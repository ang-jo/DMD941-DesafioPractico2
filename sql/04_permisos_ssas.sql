/* =====================================================================
   DMD941 - Desafío Práctico 2
   Script 04: Permiso de lectura para la cuenta de Analysis Services
   ---------------------------------------------------------------------
   Cuando el cubo se procesa, quien lee las vistas NO eres tú: es la cuenta
   del servicio de Analysis Services. Si esa cuenta no tiene permiso, el
   procesamiento falla con un error parecido a:
     "Login failed for user 'NT SERVICE\MSSQLServerOLAPService'"
   Este script le da permiso de solo lectura sobre la base de datos.

   Nota: "MSSQLServerOLAPService" es el nombre para la instancia
   predeterminada. Si instalaste una instancia con nombre (por ejemplo
   SSAS), la cuenta es NT SERVICE\MSOLAP$SSAS.
   ===================================================================== */

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals
               WHERE name = N'NT SERVICE\MSSQLServerOLAPService')
    CREATE LOGIN [NT SERVICE\MSSQLServerOLAPService] FROM WINDOWS;
GO

USE AdventureWorksDW2025;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals
               WHERE name = N'NT SERVICE\MSSQLServerOLAPService')
    CREATE USER [NT SERVICE\MSSQLServerOLAPService]
        FOR LOGIN [NT SERVICE\MSSQLServerOLAPService];
GO

ALTER ROLE db_datareader ADD MEMBER [NT SERVICE\MSSQLServerOLAPService];
GO

-- Verificación: debe aparecer una fila con el rol db_datareader
SELECT dp.name AS Usuario, r.name AS Rol
FROM sys.database_role_members AS rm
JOIN sys.database_principals AS dp ON dp.principal_id = rm.member_principal_id
JOIN sys.database_principals AS r  ON r.principal_id  = rm.role_principal_id
WHERE dp.name = N'NT SERVICE\MSSQLServerOLAPService';
GO
