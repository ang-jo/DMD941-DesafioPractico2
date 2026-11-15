/* =====================================================================
   DMD941 - Desafío Práctico 2
   Script 03: Vistas que alimentan el cubo OLAP (esquema "bi")
   ---------------------------------------------------------------------
   ¿Por qué vistas y no las tablas directamente?
   - Solo exponen las columnas que el cubo necesita (menos datos que procesar).
   - Traducen nombres al español y aplanan la jerarquía de producto
     (DimProduct -> DimProductSubcategory -> DimProductCategory) en una sola tabla.
   - Calculan la Utilidad (Ventas - Costo) una sola vez, en el origen.
   - Los nombres de columna ya son los nombres finales de atributos y medidas
     del cubo, así no hay que renombrar nada en Visual Studio.
   Se puede ejecutar completo (F5) cuantas veces sea necesario.
   ===================================================================== */

USE AdventureWorksDW2025;
GO

IF SCHEMA_ID(N'bi') IS NULL
    EXEC (N'CREATE SCHEMA bi AUTHORIZATION dbo;');
GO

/* ---------- Dimensión Fecha ----------
   Solo los años que tienen ventas (2010-2014), para que el cubo y Power BI
   no muestren años vacíos. Las claves de Trimestre y Mes son texto que
   ordena bien alfabéticamente ("2012-T1" < "2012-T2" < "2013-T1"). */
CREATE OR ALTER VIEW bi.vDimFecha
AS
SELECT  d.DateKey,
        d.FullDateAlternateKey                                  AS [Fecha],
        d.CalendarYear                                          AS [Año],
        CONCAT(d.CalendarYear, N'-T', d.CalendarQuarter)        AS [Trimestre],
        CONCAT(d.CalendarYear, N'-',
               RIGHT(CONCAT(N'0', d.MonthNumberOfYear), 2), N' ',
               d.SpanishMonthName)                              AS [Mes]
FROM dbo.DimDate AS d
WHERE d.CalendarYear BETWEEN
        (SELECT MIN(x.OrderDateKey) / 10000
           FROM (SELECT OrderDateKey FROM dbo.FactInternetSales
                 UNION ALL
                 SELECT OrderDateKey FROM dbo.FactResellerSales) AS x)
    AND (SELECT MAX(x.OrderDateKey) / 10000
           FROM (SELECT OrderDateKey FROM dbo.FactInternetSales
                 UNION ALL
                 SELECT OrderDateKey FROM dbo.FactResellerSales) AS x);
GO

/* ---------- Dimensión Producto ----------
   Jerarquía aplanada Categoría > Subcategoría > Producto.
   LEFT JOIN + ISNULL: hay productos sin subcategoría (no tienen ventas,
   pero deben existir en la dimensión para no perder filas). */
CREATE OR ALTER VIEW bi.vDimProducto
AS
SELECT  p.ProductKey,
        p.ProductAlternateKey                                           AS [Código Producto],
        p.EnglishProductName                                            AS [Producto],
        ISNULL(sc.SpanishProductSubcategoryName, N'Sin subcategoría')   AS [Subcategoría],
        ISNULL(c.SpanishProductCategoryName,     N'Sin categoría')      AS [Categoría]
FROM dbo.DimProduct AS p
LEFT JOIN dbo.DimProductSubcategory AS sc ON sc.ProductSubcategoryKey = p.ProductSubcategoryKey
LEFT JOIN dbo.DimProductCategory    AS c  ON c.ProductCategoryKey     = sc.ProductCategoryKey;
GO

/* ---------- Dimensión Territorio ----------
   Jerarquía Grupo > País > Región. Se excluye la fila "NA" (no aplica),
   que no tiene ventas. Los países quedan en inglés porque así los
   reconoce el mapa de Power BI. */
CREATE OR ALTER VIEW bi.vDimTerritorio
AS
SELECT  t.SalesTerritoryKey,
        CASE t.SalesTerritoryGroup
             WHEN N'North America' THEN N'Norteamérica'
             WHEN N'Europe'        THEN N'Europa'
             WHEN N'Pacific'       THEN N'Pacífico'
             ELSE t.SalesTerritoryGroup
        END                          AS [Grupo],
        t.SalesTerritoryCountry      AS [País],
        t.SalesTerritoryRegion       AS [Región]
FROM dbo.DimSalesTerritory AS t
WHERE t.SalesTerritoryRegion <> N'NA';
GO

/* ---------- Hechos: Ventas por Internet ----------
   CAST de la cantidad a int: la columna original es smallint y su suma
   podría desbordarse dentro del cubo. */
CREATE OR ALTER VIEW bi.vFactVentasInternet
AS
SELECT  f.SalesOrderNumber,
        f.SalesOrderLineNumber,
        f.ProductKey,
        f.OrderDateKey,
        f.SalesTerritoryKey,
        CAST(f.OrderQuantity AS int)          AS [Cantidad Internet],
        f.SalesAmount                         AS [Ventas Internet],
        f.TotalProductCost                    AS [Costo Internet],
        f.SalesAmount - f.TotalProductCost    AS [Utilidad Internet]
FROM dbo.FactInternetSales AS f;
GO

/* ---------- Hechos: Ventas por Revendedor (Reseller) ---------- */
CREATE OR ALTER VIEW bi.vFactVentasRevendedor
AS
SELECT  f.SalesOrderNumber,
        f.SalesOrderLineNumber,
        f.ProductKey,
        f.OrderDateKey,
        f.SalesTerritoryKey,
        CAST(f.OrderQuantity AS int)          AS [Cantidad Revendedor],
        f.SalesAmount                         AS [Ventas Revendedor],
        f.TotalProductCost                    AS [Costo Revendedor],
        f.SalesAmount - f.TotalProductCost    AS [Utilidad Revendedor]
FROM dbo.FactResellerSales AS f;
GO

/* ---------- Vista de apoyo para las consultas SQL de validación ----------
   Une ambos canales en una sola vista (NO se usa en el cubo). */
CREATE OR ALTER VIEW bi.vVentasCanales
AS
SELECT ProductKey, OrderDateKey, SalesTerritoryKey, N'Internet' AS Canal,
       [Cantidad Internet] AS Cantidad, [Ventas Internet] AS Ventas,
       [Costo Internet] AS Costo, [Utilidad Internet] AS Utilidad
FROM bi.vFactVentasInternet
UNION ALL
SELECT ProductKey, OrderDateKey, SalesTerritoryKey, N'Revendedor',
       [Cantidad Revendedor], [Ventas Revendedor],
       [Costo Revendedor], [Utilidad Revendedor]
FROM bi.vFactVentasRevendedor;
GO

/* ---------- Verificación ----------
   Valores esperados: Fecha 1,826 filas (2010-2014) | Producto 606 | Territorio 10
                      Internet 60,398 | Revendedor 60,855 */
SELECT N'bi.vDimFecha' AS Vista, COUNT(*) AS Filas FROM bi.vDimFecha
UNION ALL SELECT N'bi.vDimProducto',          COUNT(*) FROM bi.vDimProducto
UNION ALL SELECT N'bi.vDimTerritorio',        COUNT(*) FROM bi.vDimTerritorio
UNION ALL SELECT N'bi.vFactVentasInternet',   COUNT(*) FROM bi.vFactVentasInternet
UNION ALL SELECT N'bi.vFactVentasRevendedor', COUNT(*) FROM bi.vFactVentasRevendedor;
GO
