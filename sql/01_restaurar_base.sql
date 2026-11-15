/* =====================================================================
   DMD941 - Desafío Práctico 2
   Script 01: Restauración de AdventureWorksDW2025 (alternativa por código)
   ---------------------------------------------------------------------

   ===================================================================== */

USE master;
GO

/* ---------- BLOQUE A: ver qué archivos contiene el respaldo ---------- */
RESTORE FILELISTONLY
FROM DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\AdventureWorksDW2025.bak';
GO

/* ---------- BLOQUE B: restaurar la base de datos ----------
   InstanceDefaultDataPath / InstanceDefaultLogPath devuelven las carpetas
   predeterminadas de tu instalación, así no hay que escribirlas a mano. */
DECLARE @bak  nvarchar(400) = N'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\AdventureWorksDW2025.bak';
DECLARE @data nvarchar(400) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(400)) + N'AdventureWorksDW2025.mdf';
DECLARE @log  nvarchar(400) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS nvarchar(400)) + N'AdventureWorksDW2025_log.ldf';

RESTORE DATABASE AdventureWorksDW2025
FROM DISK = @bak
WITH
    MOVE N'AdventureWorksDW2025'     TO @data,   -- LogicalName del archivo de datos (BLOQUE A)
    MOVE N'AdventureWorksDW2025_log' TO @log,    -- LogicalName del archivo de log  (BLOQUE A)
    RECOVERY,
    STATS = 10;                                  -- muestra el avance cada 10 %
GO

/* ---------- BLOQUE C: verificar que la base quedó accesible ---------- */
SELECT name                AS BaseDeDatos,
       state_desc          AS Estado,              -- debe decir ONLINE
       compatibility_level AS NivelCompatibilidad,
       create_date         AS FechaRestauracion
FROM sys.databases
WHERE name = N'AdventureWorksDW2025';
GO

USE AdventureWorksDW2025;
GO

-- Conteo rápido de las tablas que usará el proyecto (valores esperados en comentarios)
SELECT N'FactInternetSales' AS Tabla, COUNT(*) AS Filas FROM dbo.FactInternetSales   -- 60,398
UNION ALL SELECT N'FactResellerSales', COUNT(*) FROM dbo.FactResellerSales           -- 60,855
UNION ALL SELECT N'DimProduct',        COUNT(*) FROM dbo.DimProduct                  -- 606
UNION ALL SELECT N'DimDate',           COUNT(*) FROM dbo.DimDate                     -- 3,652
UNION ALL SELECT N'DimSalesTerritory', COUNT(*) FROM dbo.DimSalesTerritory;          -- 11
GO
