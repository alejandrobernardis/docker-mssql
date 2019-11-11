-- =============================================================================
-- Author: Alejandro M. BERNARDIS
-- Email: alejandro.bernardis at gmail.com
-- Created: 2019/11/11 10:49
--
-- Change History:
-- ~~~~~~~~~~~~~~~
-- 20/01/2019 (i0608156): Versión inicial.
--
-- =============================================================================

USE [master]
GO

-- Usuario SA forzado a cambiar la contraseña
ALTER LOGIN sa
  WITH PASSWORD='Password.01' MUST_CHANGE,
  CHECK_EXPIRATION=ON,
  CHECK_POLICY=ON
;
GO

PRINT "Modified SA user... Done."
GO

IF OBJECT_ID(N'[dbo].[sp_create_login]', N'P') IS NOT NULL
  DROP PROCEDURE [dbo].[sp_create_login]
GO

CREATE PROCEDURE [dbo].[sp_create_login]
    @username      NVARCHAR(128)
  , @password      NVARCHAR(128) = 'Password.01'
  , @service       BIT = 0
  , @sysadmin      BIT = 0
  , @bulkadmin     BIT = 0
  , @dbcreator     BIT = 0
  , @processadmin  BIT = 0
  , @securityadmin BIT = 0
  , @setupadmin    BIT = 0

AS
  -- ===========================================================================
  --
  -- Description: Permite crear un nuevo login.
  --
  -- Arguments
  -- ~~~~~~~~~
  --    username      > Usuario Ex: A0123456
  --    password      > Contraseña (default='PassW0rd')
  --    service       > Usuario de Servicio (0=NO (default), 1=YES)
  --
  --    # Roles
  --    sysadmin      > Administrador (0=DROP (default), 1=ADD)
  --    bulkadmin     > Craga Masiva (0=DROP (default), 1=ADD)
  --    dbcreator     > Creación de Bases de Datos (0=DROP (default), 1=ADD)
  --    processadmin  > Procesos (0=DROP (default), 1=ADD)
  --    securityadmin > Seguridad (0=DROP (default), 1=ADD)
  --    setupadmin    > Linked Server (0=DROP (default), 1=ADD)
  --
  -- ===========================================================================
  SET NOCOUNT ON;

  DECLARE
      @return INT = 0
    , @Q NVARCHAR(max) = N'USE [master];
IF SUSER_ID(N''{username}'') is NULL
  CREATE LOGIN [{username}] WITH PASSWORD=N''{password}'' {change}
    , DEFAULT_DATABASE=[master]
    , DEFAULT_LANGUAGE=[us_english]
    , CHECK_EXPIRATION={check}
    , CHECK_POLICY={check}
  ;
IF SUSER_ID(N''{username}'') is not NULL
  BEGIN
    -- ALTER SERVER ROLE [bulkadmin] {bulkadmin} MEMBER [{username}];
    ALTER SERVER ROLE [dbcreator] {dbcreator} MEMBER [{username}];
    ALTER SERVER ROLE [processadmin] {processadmin} MEMBER [{username}];
    ALTER SERVER ROLE [securityadmin] {securityadmin} MEMBER [{username}];
    ALTER SERVER ROLE [setupadmin] {setupadmin} MEMBER [{username}];
    ALTER SERVER ROLE [sysadmin] {sysadmin} MEMBER [{username}];
  END';

  IF @sysadmin=1 or @service=1
    BEGIN
      SET @bulkadmin=0
      SET @dbcreator=0
      SET @processadmin=0
      SET @securityadmin=0
      SET @setupadmin=0
    END

  SET @Q = REPLACE(@Q, N'{bulkadmin}'    , CASE WHEN @bulkadmin=1     THEN N'ADD' ELSE N'DROP' END)
  SET @Q = REPLACE(@Q, N'{dbcreator}'    , CASE WHEN @dbcreator=1     THEN N'ADD' ELSE N'DROP' END)
  SET @Q = REPLACE(@Q, N'{processadmin}' , CASE WHEN @processadmin=1  THEN N'ADD' ELSE N'DROP' END)
  SET @Q = REPLACE(@Q, N'{securityadmin}', CASE WHEN @securityadmin=1 THEN N'ADD' ELSE N'DROP' END)
  SET @Q = REPLACE(@Q, N'{setupadmin}'   , CASE WHEN @setupadmin=1    THEN N'ADD' ELSE N'DROP' END)
  SET @Q = REPLACE(@Q, N'{sysadmin}'     , CASE WHEN @sysadmin=1      THEN N'ADD' ELSE N'DROP' END)
  SET @Q = REPLACE(@Q, N'{check}'        , CASE WHEN @service=1       THEN N'OFF' ELSE N'ON' END)
  SET @Q = REPLACE(@Q, N'{change}'       , CASE WHEN @service=1       THEN N''    ELSE N'MUST_CHANGE' END)
  SET @Q = REPLACE(@Q, N'{password}'     , @password)
  SET @Q = REPLACE(@Q, N'{username}'     , @username)

  BEGIN TRY
    EXEC (@Q)
  END TRY
  BEGIN CATCH
    PRINT CONCAT(' ! Added User ', @username, '... Error.')
    PRINT CONCAT('  + (#', ERROR_NUMBER(), ') ', ERROR_MESSAGE())
    SET @return = ERROR_NUMBER()
  END CATCH

RETURN @return
GO

PRINT "Created sp_create_login... Done."
GO

IF OBJECT_ID(N'[dbo].[sp_add_login]', N'P') IS NOT NULL
  DROP PROCEDURE [dbo].[sp_add_login]
GO

CREATE PROCEDURE [dbo].[sp_add_login]
    @username         NVARCHAR(128)
  , @database         NVARCHAR(max) = NULL -- (NULL) ALL / String or JSON
  , @owner            BIT = 0
  , @reader           BIT = 0
  , @writer           BIT = 0
  , @security         BIT = 0
  , @access           BIT = 0
  , @backup           BIT = 0
  , @execute          BIT = 0
  , @ignore_read_only BIT = 1
AS
  -- ===========================================================================
  --
  -- Description: Permite un login a una o varias base de datos.
  --
  -- Arguments
  -- ~~~~~~~~~
  --    username > Usuario Ex: A0123456
  --    database > Base de Datos ([STRING]=N'db_name';
  --                              [JSON]=N'{"databases": ["db_name", "..."]}')
  --
  --    # Roles
  --    owner    > Dueño (0=DROP (default), 1=ADD)
  --    reader   > Lectura (0=DROP (default), 1=ADD)
  --    writer   > Escritura (0=DROP (default), 1=ADD)
  --    security > Seguridad (0=DROP (default), 1=ADD)
  --    access   > Acceso (0=DROP (default), 1=ADD)
  --    execute  > Ejecución (0=DENY (default), 1=GRANT)
  --    backup   > Backuup (0=DENY (default), 1=GRANT)
  --
  -- ===========================================================================
  SET NOCOUNT ON;
  DECLARE @return INT = 0;

  IF SUSER_ID(@username) is NULL
    BEGIN
      SET @return = 1
      GOTO Exit_Return
    END

  IF IS_SRVROLEMEMBER('sysadmin', @username) = 1
    BEGIN
      SET @return = 2
      GOTO Exit_Return
    END

  DECLARE @Read_Only_DB TABLE([name] VARCHAR(128) NOT NULL);

  INSERT INTO @Read_Only_DB
    SELECT [name]
      FROM sys.databases
        WHERE is_read_only=1
  ;

  DECLARE @Databases TABLE(
      [ID]   INT          NOT NULL IDENTITY (1, 1)
    , [name] VARCHAR(128) NOT NULL
  );

  IF ISJSON(@database) = 1
    INSERT INTO @Databases
      SELECT [value]
        FROM OPENJSON(@database, '$.databases')
          WHERE [type] = 1
      ;
  ELSE IF @database IS NOT NULL
    INSERT INTO @Databases VALUES (@database)
  ELSE
    INSERT INTO @Databases
      SELECT [name]
        FROM [sys].[databases]
          WHERE [name] not in ('msdb','model','tempdb','master')
        ORDER BY [name] ASC
      ;

  DECLARE
      @i         INT
    , @t         INT
    , @read_only BIT = 0
    , @enabled   BIT = 1
    , @Q         NVARCHAR(max)
    , @kill      NVARCHAR(max)
  ;

  SELECT @i=MIN(ID), @t=MAX(ID) FROM @Databases;
  WHILE @i <= @t
    BEGIN
      SELECT @database=[name] FROM @Databases WHERE [ID]=@i;

      SET @Q = 'USE [{database}];
IF database_principal_id(''{username}'') is NULL
  CREATE USER [{username}] FOR LOGIN [{username}] WITH DEFAULT_SCHEMA=[dbo];
ALTER ROLE [db_owner] {owner} MEMBER [{username}];
ALTER ROLE [db_datareader] {reader} MEMBER [{username}];
ALTER ROLE [db_datawriter] {writer} MEMBER [{username}];
ALTER ROLE [db_securityadmin] {security} MEMBER [{username}];
ALTER ROLE [db_accessadmin] {access} MEMBER [{username}];
{execute} EXECUTE ON SCHEMA::dbo to [{username}];
{backup} BACKUP DATABASE TO [{username}];
{backup} BACKUP LOG TO [{username}];';
      SELECT @read_only=1 FROM @Read_Only_DB WHERE [name]=@database
      SET @enabled = CASE WHEN 1 IN (@owner, @read_only) THEN 0 ELSE 1 END
      SET @Q = REPLACE(@Q, N'{owner}'   , CASE WHEN @owner=1 AND @read_only=0  THEN N'ADD'   ELSE N'DROP' END)
      SET @Q = REPLACE(@Q, N'{reader}'  , CASE WHEN (@enabled=1 AND @reader=1) OR @read_only=1
                                                                               THEN N'ADD'   ELSE N'DROP' END)
      SET @Q = REPLACE(@Q, N'{writer}'  , CASE WHEN @enabled=1 AND @writer=1   THEN N'ADD'   ELSE N'DROP' END)
      SET @Q = REPLACE(@Q, N'{security}', CASE WHEN @enabled=1 AND @security=1 THEN N'ADD'   ELSE N'DROP' END)
      SET @Q = REPLACE(@Q, N'{access}'  , CASE WHEN @enabled=1 AND @access=1   THEN N'ADD'   ELSE N'DROP' END)
      SET @Q = REPLACE(@Q, N'{execute}' , CASE WHEN (@enabled=1 AND @execute=1) OR @owner=1
                                                                               THEN N'GRANT' ELSE N'REVOKE' END)
      SET @Q = REPLACE(@Q, N'{backup}'  , CASE WHEN @read_only=0 AND @backup=1 THEN N'GRANT' ELSE N'DENY' END)
      SET @Q = REPLACE(@Q, N'{username}', @username)
      SET @Q = REPLACE(@Q, N'{database}', @database)

      BEGIN TRY
        IF @read_only=1 AND @ignore_read_only=0
          BEGIN
            SELECT @kill=@kill+'kill '+CONVERT(varchar(5), spid)+';'
              FROM master..sysprocesses WHERE [dbid] = DB_ID(@database)
            EXEC (@kill + 'ALTER DATABASE ' + @database + ' SET READ_WRITE WITH NO_WAIT;')
          END
        EXEC (@Q)
        IF @read_only=1 AND @ignore_read_only=0
          EXEC ('ALTER DATABASE ' + @database + ' SET READ_ONLY WITH NO_WAIT')
      END TRY
      BEGIN CATCH
        PRINT CONCAT(' ! Added User ', @database, '... Error.')
        PRINT CONCAT('  + (#', ERROR_NUMBER(), ') ', ERROR_MESSAGE())
        SET @return = ERROR_NUMBER()
        IF @ignore_read_only=1 AND @return IN (3906, 3930)
          GOTO Next_Database
        GOTO Exit_Error
      END CATCH

      Next_Database:
      SET @i += 1
      SET @enabled = 1
      SET @read_only = 0
    END

  Exit_Error:
  IF @@ERROR <> 0 OR @return = 0
    SET @return = @@ERROR

Exit_Return:
RETURN @return
GO

PRINT "Created sp_add_login... Done."
GO

-- =============================================================================
--
-- Definición de usuarios.
--
-- =============================================================================

IF OBJECT_ID(N'[dbo].[sp_create_login]', N'P') IS NULL
  GOTO Exit_Setup

SET NOCOUNT ON;
DECLARE @Users TABLE(
    [ID] INT IDENTITY (1, 1)
  , [name] NVARCHAR(128)
);

INSERT INTO @Users VALUES
    ('I0000000')
  , ('I0000001')
  , ('I0000002')
;

DECLARE
  @id INT,
  @total INT,
  @username NVARCHAR(128)
;

SELECT @id=MIN([ID]), @total=MAX([ID]) FROM @Users
WHILE @id <= @total
  BEGIN
    SELECT @username=[name] FROM @Users WHERE [ID]=@id;
    BEGIN TRY
      PRINT CONCAT('Created ', @username, ' user... Done.')
      EXEC sp_create_login @username, @sysadmin=1
    END TRY
    BEGIN CATCH
      PRINT CONCAT(' ! Created Login ', @username, '... Error.')
      PRINT CONCAT('  + (#', ERROR_NUMBER(), ') ', ERROR_MESSAGE())
    END CATCH
    SET @id += 1
  END

EXEC sp_create_login 'dba', "x0pa%%word.01", @service=1, @sysadmin=1
EXEC sp_create_login 'support', "x0pa%%word.02", @service=1, @sysadmin=1
EXEC sp_create_login '0x00', "x0pa%%word.03", @service=1, @sysadmin=1
EXEC sp_create_login '0x83', "x0pa%%word.07", @service=1, @sysadmin=1
SET NOCOUNT OFF;

-- =============================================================================

Exit_Setup:
GO
