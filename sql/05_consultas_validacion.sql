/* =====================================================================
   DMD941 - Desafío Práctico 2
   Script 05: Consultas SQL que responden las preguntas de negocio
   ---------------------------------------------------------------------
   Sirven para dos cosas:
   1. Responder las preguntas directamente sobre el data warehouse.
   2. Validar el cubo: los totales deben coincidir con los de las
      consultas MDX (archivo mdx/consultas_cubo.mdx).

   Técnicas de optimización usadas:
   - Se agrega una sola vez por consulta (GROUP BY) y se calculan rankings
     y variaciones con funciones de ventana (RANK, LAG) en lugar de
     subconsultas repetidas.
   - Las uniones se hacen por claves enteras (ProductKey, DateKey), que
     están indexadas en el data warehouse.
   - El Top 10 se calcula una vez en una CTE y se reutiliza.
   Para medir el costo: activa SET STATISTICS IO, TIME ON (abajo) y revisa
   la pestaña "Mensajes".
   ===================================================================== */

USE AdventureWorksDW2025;
GO
SET STATISTICS IO, TIME ON;
GO

/* =====================================================================
   PREGUNTA (a): categorías y subcategorías con mayor volumen de ventas
   por año, y su tendencia trimestre a trimestre.
   ===================================================================== */

-- (a.1) Ventas y unidades por categoría y año, con su peso en el año
SELECT  f.[Año],
        p.[Categoría],
        SUM(v.Cantidad)  AS Unidades,
        SUM(v.Ventas)    AS Ventas,
        CAST(100.0 * SUM(v.Ventas)
             / SUM(SUM(v.Ventas)) OVER (PARTITION BY f.[Año]) AS decimal(5,2)) AS PctDelAnio
FROM bi.vVentasCanales AS v
JOIN bi.vDimProducto   AS p ON p.ProductKey = v.ProductKey
JOIN bi.vDimFecha      AS f ON f.DateKey    = v.OrderDateKey
GROUP BY f.[Año], p.[Categoría]
ORDER BY f.[Año], Ventas DESC;
GO

-- (a.2) Top 3 subcategorías de cada año (por ventas en dólares y por unidades)
WITH SubcatAnio AS (
    SELECT  f.[Año], p.[Categoría], p.[Subcategoría],
            SUM(v.Cantidad) AS Unidades,
            SUM(v.Ventas)   AS Ventas,
            RANK() OVER (PARTITION BY f.[Año] ORDER BY SUM(v.Ventas)   DESC) AS RankVentas,
            RANK() OVER (PARTITION BY f.[Año] ORDER BY SUM(v.Cantidad) DESC) AS RankUnidades
    FROM bi.vVentasCanales AS v
    JOIN bi.vDimProducto   AS p ON p.ProductKey = v.ProductKey
    JOIN bi.vDimFecha      AS f ON f.DateKey    = v.OrderDateKey
    GROUP BY f.[Año], p.[Categoría], p.[Subcategoría]
)
SELECT [Año], [Categoría], [Subcategoría], Unidades, Ventas, RankVentas, RankUnidades
FROM SubcatAnio
WHERE RankVentas <= 3 OR RankUnidades <= 3
ORDER BY [Año], RankVentas;
GO

-- (a.3) Tendencia trimestral por categoría y variación contra el trimestre anterior
WITH CatTrimestre AS (
    SELECT  p.[Categoría], f.[Trimestre], SUM(v.Ventas) AS Ventas
    FROM bi.vVentasCanales AS v
    JOIN bi.vDimProducto   AS p ON p.ProductKey = v.ProductKey
    JOIN bi.vDimFecha      AS f ON f.DateKey    = v.OrderDateKey
    GROUP BY p.[Categoría], f.[Trimestre]
)
SELECT  [Categoría], [Trimestre], Ventas,
        LAG(Ventas) OVER (PARTITION BY [Categoría] ORDER BY [Trimestre]) AS VentasTrimAnterior,
        CAST(100.0 * (Ventas - LAG(Ventas) OVER (PARTITION BY [Categoría] ORDER BY [Trimestre]))
             / NULLIF(LAG(Ventas) OVER (PARTITION BY [Categoría] ORDER BY [Trimestre]), 0)
             AS decimal(10,2)) AS VariacionPct
FROM CatTrimestre
ORDER BY [Categoría], [Trimestre];
GO

/* =====================================================================
   PREGUNTA (b): territorios con mayor rentabilidad, y comparación de
   ventas por Internet frente a Revendedor en cada uno.
   ===================================================================== */

-- (b.1) Rentabilidad por región, separada por canal, con ranking
SELECT  RANK() OVER (ORDER BY SUM(v.Utilidad) DESC) AS Ranking,
        t.[Grupo], t.[País], t.[Región],
        SUM(CASE WHEN v.Canal = N'Internet'   THEN v.Ventas   END) AS VentasInternet,
        SUM(CASE WHEN v.Canal = N'Revendedor' THEN v.Ventas   END) AS VentasRevendedor,
        SUM(v.Ventas)                                              AS VentasTotales,
        SUM(CASE WHEN v.Canal = N'Internet'   THEN v.Utilidad END) AS UtilidadInternet,
        SUM(CASE WHEN v.Canal = N'Revendedor' THEN v.Utilidad END) AS UtilidadRevendedor,
        SUM(v.Utilidad)                                            AS UtilidadTotal,
        CAST(100.0 * SUM(v.Utilidad) / NULLIF(SUM(v.Ventas), 0) AS decimal(6,2)) AS MargenPct,
        CAST(100.0 * SUM(CASE WHEN v.Canal = N'Internet' THEN v.Ventas END)
             / NULLIF(SUM(v.Ventas), 0) AS decimal(6,2))                         AS PctVentasInternet
FROM bi.vVentasCanales AS v
JOIN bi.vDimTerritorio AS t ON t.SalesTerritoryKey = v.SalesTerritoryKey
GROUP BY t.[Grupo], t.[País], t.[Región]
ORDER BY UtilidadTotal DESC;
GO

-- (b.2) Margen por canal en toda la empresa (explica la diferencia entre canales)
SELECT  v.Canal,
        SUM(v.Ventas)   AS Ventas,
        SUM(v.Costo)    AS Costo,
        SUM(v.Utilidad) AS Utilidad,
        CAST(100.0 * SUM(v.Utilidad) / NULLIF(SUM(v.Ventas), 0) AS decimal(6,2)) AS MargenPct
FROM bi.vVentasCanales AS v
GROUP BY v.Canal;
GO

/* =====================================================================
   PREGUNTA (c): los 10 productos más rentables y su distribución en el
   tiempo (por año y trimestre).
   ===================================================================== */

-- (c.1) Top 10 productos por utilidad total (ambos canales)
SELECT TOP (10)
        p.[Producto], p.[Subcategoría],
        SUM(v.Cantidad) AS Unidades,
        SUM(v.Ventas)   AS Ventas,
        SUM(v.Utilidad) AS Utilidad,
        CAST(100.0 * SUM(v.Utilidad) / NULLIF(SUM(v.Ventas), 0) AS decimal(6,2)) AS MargenPct
FROM bi.vVentasCanales AS v
JOIN bi.vDimProducto   AS p ON p.ProductKey = v.ProductKey
GROUP BY p.[Producto], p.[Subcategoría]
ORDER BY Utilidad DESC;
GO

-- (c.2) Ventas de cada producto del Top 10 por año (tabla dinámica con PIVOT)
WITH Top10 AS (
    SELECT TOP (10) p.[Producto]
    FROM bi.vVentasCanales AS v
    JOIN bi.vDimProducto   AS p ON p.ProductKey = v.ProductKey
    GROUP BY p.[Producto]
    ORDER BY SUM(v.Utilidad) DESC
),
Base AS (
    SELECT p.[Producto], f.[Año], v.Ventas
    FROM bi.vVentasCanales AS v
    JOIN bi.vDimProducto   AS p ON p.ProductKey = v.ProductKey
    JOIN bi.vDimFecha      AS f ON f.DateKey    = v.OrderDateKey
    WHERE p.[Producto] IN (SELECT [Producto] FROM Top10)
)
SELECT [Producto], [2010], [2011], [2012], [2013], [2014]
FROM Base
PIVOT (SUM(Ventas) FOR [Año] IN ([2010], [2011], [2012], [2013], [2014])) AS pv
ORDER BY [Producto];
GO

-- (c.3) Ventas y utilidad del Top 10 (en conjunto) por trimestre
WITH Top10 AS (
    SELECT TOP (10) p.[Producto]
    FROM bi.vVentasCanales AS v
    JOIN bi.vDimProducto   AS p ON p.ProductKey = v.ProductKey
    GROUP BY p.[Producto]
    ORDER BY SUM(v.Utilidad) DESC
)
SELECT  f.[Año], f.[Trimestre],
        SUM(v.Cantidad) AS Unidades,
        SUM(v.Ventas)   AS Ventas,
        SUM(v.Utilidad) AS Utilidad
FROM bi.vVentasCanales AS v
JOIN bi.vDimProducto   AS p ON p.ProductKey = v.ProductKey
JOIN bi.vDimFecha      AS f ON f.DateKey    = v.OrderDateKey
WHERE p.[Producto] IN (SELECT [Producto] FROM Top10)
GROUP BY f.[Año], f.[Trimestre]
ORDER BY f.[Trimestre];
GO

SET STATISTICS IO, TIME OFF;
GO
