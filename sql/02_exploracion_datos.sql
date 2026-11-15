/* =====================================================================
   DMD941 - Desafío Práctico 2
   Script 02: Carga y exploración de datos
   ---------------------------------------------------------------------
   Objetivo: conocer las tablas de hechos y dimensiones, sus relaciones y
   la calidad de los datos, para decidir cuáles alimentan el cubo.
   Ejecuta cada bloque por separado (selecciónalo y presiona F5) y toma
   una captura de cada resultado para el informe.
   ===================================================================== */

USE AdventureWorksDW2025;
GO

/* 1. Inventario: todas las tablas, clasificadas en hechos y dimensiones */
SELECT  s.name AS Esquema,
        t.name AS Tabla,
        CASE WHEN t.name LIKE N'Fact%' THEN N'Hechos'
             WHEN t.name LIKE N'Dim%'  THEN N'Dimensión'
             ELSE N'Otra' END AS Tipo,
        SUM(p.rows) AS Filas
FROM sys.tables AS t
JOIN sys.schemas AS s     ON s.schema_id = t.schema_id
JOIN sys.partitions AS p  ON p.object_id = t.object_id
                         AND p.index_id IN (0, 1)      -- montón o índice agrupado: evita contar filas dos veces
GROUP BY s.name, t.name
ORDER BY Tipo DESC, Filas DESC;
GO

/* 2. Relaciones: ¿con qué dimensiones se une cada tabla de hechos? */
SELECT  OBJECT_NAME(fk.parent_object_id)                              AS TablaHechos,
        COL_NAME(fkc.parent_object_id, fkc.parent_column_id)          AS ColumnaHechos,
        OBJECT_NAME(fk.referenced_object_id)                          AS TablaDimension,
        COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id)  AS ColumnaDimension
FROM sys.foreign_keys AS fk
JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
WHERE OBJECT_NAME(fk.parent_object_id) IN (N'FactInternetSales', N'FactResellerSales')
ORDER BY TablaHechos, TablaDimension;
GO

/* 3. Columnas de la tabla de hechos principal (identificar medidas y claves) */
SELECT COLUMN_NAME AS Columna, DATA_TYPE AS Tipo, IS_NULLABLE AS AceptaNulos
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = N'dbo' AND TABLE_NAME = N'FactInternetSales'
ORDER BY ORDINAL_POSITION;
GO

/* 4. Muestra de datos de cada tabla relevante */
SELECT TOP (5) ProductKey, OrderDateKey, SalesTerritoryKey, SalesOrderNumber,
       OrderQuantity, SalesAmount, TotalProductCost
FROM dbo.FactInternetSales;

SELECT TOP (5) ProductKey, OrderDateKey, SalesTerritoryKey, SalesOrderNumber,
       OrderQuantity, SalesAmount, TotalProductCost
FROM dbo.FactResellerSales;

SELECT TOP (5) p.ProductKey, p.EnglishProductName,
       sc.SpanishProductSubcategoryName, c.SpanishProductCategoryName
FROM dbo.DimProduct AS p
JOIN dbo.DimProductSubcategory AS sc ON sc.ProductSubcategoryKey = p.ProductSubcategoryKey
JOIN dbo.DimProductCategory    AS c  ON c.ProductCategoryKey     = sc.ProductCategoryKey;

SELECT SalesTerritoryKey, SalesTerritoryRegion, SalesTerritoryCountry, SalesTerritoryGroup
FROM dbo.DimSalesTerritory;
GO

/* 5. Periodo cubierto y totales por canal (primer vistazo al negocio) */
SELECT N'Internet' AS Canal,
       MIN(OrderDate) AS PrimeraVenta, MAX(OrderDate) AS UltimaVenta,
       COUNT(DISTINCT SalesOrderNumber) AS Ordenes,
       SUM(OrderQuantity)  AS Unidades,
       SUM(SalesAmount)    AS Ventas,
       SUM(SalesAmount - TotalProductCost) AS Utilidad
FROM dbo.FactInternetSales
UNION ALL
SELECT N'Revendedor',
       MIN(OrderDate), MAX(OrderDate),
       COUNT(DISTINCT SalesOrderNumber),
       SUM(OrderQuantity),
       SUM(SalesAmount),
       SUM(SalesAmount - TotalProductCost)
FROM dbo.FactResellerSales;
GO

/* 6. Ventas por año calendario: ¿hay años incompletos? */
SELECT d.CalendarYear AS Anio,
       COUNT(DISTINCT d.MonthNumberOfYear) AS MesesConVentas,
       SUM(v.SalesAmount) AS Ventas
FROM (SELECT OrderDateKey, SalesAmount FROM dbo.FactInternetSales
      UNION ALL
      SELECT OrderDateKey, SalesAmount FROM dbo.FactResellerSales) AS v
JOIN dbo.DimDate AS d ON d.DateKey = v.OrderDateKey
GROUP BY d.CalendarYear
ORDER BY d.CalendarYear;
GO

/* 7. Calidad de datos: claves huérfanas y productos sin categoría
      (todas las columnas deberían devolver 0) */
SELECT
  (SELECT COUNT(*) FROM dbo.FactInternetSales f
     WHERE NOT EXISTS (SELECT 1 FROM dbo.DimProduct p WHERE p.ProductKey = f.ProductKey))               AS InternetSinProducto,
  (SELECT COUNT(*) FROM dbo.FactResellerSales f
     WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate d WHERE d.DateKey = f.OrderDateKey))                   AS RevendedorSinFecha,
  (SELECT COUNT(*) FROM dbo.FactInternetSales f
     JOIN dbo.DimProduct p ON p.ProductKey = f.ProductKey WHERE p.ProductSubcategoryKey IS NULL)        AS InternetSinCategoria,
  (SELECT COUNT(*) FROM dbo.FactResellerSales f
     JOIN dbo.DimProduct p ON p.ProductKey = f.ProductKey WHERE p.ProductSubcategoryKey IS NULL)        AS RevendedorSinCategoria,
  (SELECT COUNT(*) FROM dbo.FactInternetSales WHERE SalesAmount IS NULL OR TotalProductCost IS NULL)    AS InternetMontosNulos;
GO

/* 8. Jerarquía de productos: categorías y cuántas subcategorías/productos tienen */
SELECT c.SpanishProductCategoryName AS Categoria,
       COUNT(DISTINCT sc.ProductSubcategoryKey) AS Subcategorias,
       COUNT(DISTINCT p.EnglishProductName)     AS Productos
FROM dbo.DimProductCategory AS c
JOIN dbo.DimProductSubcategory AS sc ON sc.ProductCategoryKey   = c.ProductCategoryKey
JOIN dbo.DimProduct            AS p  ON p.ProductSubcategoryKey = sc.ProductSubcategoryKey
GROUP BY c.SpanishProductCategoryName
ORDER BY Productos DESC;
GO

/* 9. Por qué agrupar productos por nombre y no por ProductKey:
      DimProduct guarda historial de precios (dimensión lentamente cambiante),
      así que un mismo producto puede tener varias filas (varios ProductKey). */
SELECT TOP (10) EnglishProductName AS Producto, COUNT(*) AS VersionesEnDimProduct
FROM dbo.DimProduct
GROUP BY EnglishProductName
HAVING COUNT(*) > 1
ORDER BY VersionesEnDimProduct DESC, Producto;
GO
