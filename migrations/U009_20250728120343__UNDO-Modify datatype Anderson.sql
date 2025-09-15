SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Altering [dbo].[LongStoredProc]'
GO
IF OBJECT_ID(N'[dbo].[LongStoredProc]', 'P') IS NOT NULL
EXEC sp_executesql N'ALTER PROCEDURE [dbo].[LongStoredProc]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @DatabaseName NVARCHAR(128),
        @SchemaName NVARCHAR(128),
        @TableName NVARCHAR(128),
        @ColumnName NVARCHAR(128),
        @SQL NVARCHAR(MAX),
        @RowCount INT,
        @IsNullable BIT,
        @DataType NVARCHAR(128),
        @Ordinal INT,
        @Counter INT = 0,
        @HasIdentity BIT,
        @Now DATETIME = GETDATE(),
        @LogMessage NVARCHAR(512);

    CREATE TABLE #TableDetails (
        SchemaName NVARCHAR(128),
        TableName NVARCHAR(128),
        ColumnName NVARCHAR(128),
        DataType NVARCHAR(128),
        IsNullable BIT,
        Ordinal INT,
        HasIdentity BIT
    );

    CREATE TABLE #ColumnStats (
        SchemaName NVARCHAR(128),
        TableName NVARCHAR(128),
        ColumnName NVARCHAR(128),
        IsTextColumn BIT,
        IsHighOrdinal BIT,
        LogNote NVARCHAR(256)
    );

    CREATE TABLE #Log (
        LogTime DATETIME,
        Message NVARCHAR(512)
    );

    DECLARE db_cursor CURSOR FOR
    SELECT name FROM sys.databases WHERE state_desc = ''ONLINE'';

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @LogMessage = ''Processing database: '' + @DatabaseName;
        INSERT INTO #Log VALUES (@Now, @LogMessage);

        SET @SQL = ''
        USE ['' + @DatabaseName + ''];
        INSERT INTO #TableDetails
        SELECT 
            s.name AS SchemaName,
            t.name AS TableName,
            c.name AS ColumnName,
            ty.name AS DataType,
            c.is_nullable,
            c.column_id,
            CASE WHEN ic.column_id IS NOT NULL THEN 1 ELSE 0 END AS HasIdentity
        FROM sys.tables t
        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
        INNER JOIN sys.columns c ON t.object_id = c.object_id
        INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
        LEFT JOIN sys.identity_columns ic ON c.object_id = ic.object_id AND c.column_id = ic.column_id;
        '';
        
        EXEC sp_executesql @SQL;

        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END

    CLOSE db_cursor;
    DEALLOCATE db_cursor;

    DECLARE table_cursor CURSOR FOR
    SELECT SchemaName, TableName, ColumnName, DataType, IsNullable, Ordinal, HasIdentity
    FROM #TableDetails;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor 
    INTO @SchemaName, @TableName, @ColumnName, @DataType, @IsNullable, @Ordinal, @HasIdentity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Counter += 1;

        -- Logic for column stats
        DECLARE @IsTextColumn BIT = 0;
        DECLARE @IsHighOrdinal BIT = 0;
        DECLARE @Note NVARCHAR(256) = '''';

        IF @DataType IN (''varchar'', ''nvarchar'', ''text'')
        BEGIN
            SET @IsTextColumn = 1;
            SET @Note = ''Text column'';
            PRINT ''Text column: '' + @ColumnName;
        END

        IF @Ordinal > 10
        BEGIN
            SET @IsHighOrdinal = 1;
            SET @Note = CONCAT(@Note, '' | High Ordinal'');
            PRINT ''Column has high ordinal position: '' + @ColumnName;
        END

        INSERT INTO #ColumnStats
        VALUES (@SchemaName, @TableName, @ColumnName, @IsTextColumn, @IsHighOrdinal, @Note);

        -- Dummy loop to simulate processing time
        DECLARE @dummyLoop INT = 0;
        WHILE @dummyLoop < 3
        BEGIN
            SET @dummyLoop += 1;
            -- simulate delay
        END

        -- Log each row
        SET @LogMessage = ''Processed column '' + @ColumnName + '' from table '' + @TableName;
        INSERT INTO #Log VALUES (GETDATE(), @LogMessage);

        FETCH NEXT FROM table_cursor 
        INTO @SchemaName, @TableName, @ColumnName, @DataType, @IsNullable, @Ordinal, @HasIdentity;
    END

    CLOSE table_cursor;
    DEALLOCATE table_cursor;

    -- Extra pass: summarize text column stats
    DECLARE @TextColumnCount INT;
    SELECT @TextColumnCount = COUNT(*) FROM #ColumnStats WHERE IsTextColumn = 1;

    PRINT ''Text columns found: '' + CAST(@TextColumnCount AS NVARCHAR);

    -- Output stats
    SELECT TOP 10 * FROM #ColumnStats ORDER BY SchemaName, TableName;

    -- Dummy aggregation for more rows
    SELECT 
        SchemaName,
        COUNT(*) AS ColumnCount,
        SUM(CASE WHEN IsTextColumn = 1 THEN 1 ELSE 0 END) AS TextColumns,
        SUM(CASE WHEN IsHighOrdinal = 1 THEN 1 ELSE 0 END) AS HighOrdinalColumns
    INTO #SchemaSummary
    FROM #ColumnStats
    GROUP BY SchemaName;

    SELECT * FROM #SchemaSummary;

    -- Cleanup and final log
    SET @LogMessage = ''Total columns processed: '' + CAST(@Counter AS NVARCHAR);
    INSERT INTO #Log VALUES (GETDATE(), @LogMessage);

    -- Output final log
    SELECT * FROM #Log ORDER BY LogTime;

    -- Final summary
    SELECT 
        COUNT(*) AS TotalColumns,
        SUM(CASE WHEN IsNullable = 1 THEN 1 ELSE 0 END) AS NullableColumns,
        SUM(CASE WHEN HasIdentity = 1 THEN 1 ELSE 0 END) AS IdentityColumns
    FROM #TableDetails;

    -- Drop temp tables
    DROP TABLE #ColumnStats;
    DROP TABLE #Log;
    DROP TABLE #TableDetails;
    DROP TABLE #SchemaSummary;

    PRINT ''Demo_LongStoredProc_Double completed.'';

END;
'
GO

SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT ON
GO
SET DATEFORMAT YMD
GO
SET XACT_ABORT ON
GO

