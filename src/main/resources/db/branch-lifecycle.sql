-- Upgrade existing databases without removing staff, schedules or attendance.
IF OBJECT_ID(N'dbo.user_schedules') IS NOT NULL AND COL_LENGTH(N'dbo.user_schedules', N'temporary_transfer') IS NULL
    ALTER TABLE dbo.user_schedules ADD temporary_transfer BIT NOT NULL CONSTRAINT df_schedule_temporary_transfer DEFAULT 0 WITH VALUES;

IF OBJECT_ID(N'dbo.users') IS NOT NULL AND COL_LENGTH(N'dbo.users', N'employment_status') IS NULL
    ALTER TABLE dbo.users ADD employment_status VARCHAR(24) NOT NULL CONSTRAINT df_users_employment_status DEFAULT 'ACTIVE' WITH VALUES;

IF OBJECT_ID(N'dbo.stores') IS NOT NULL AND COL_LENGTH(N'dbo.stores', N'closed_at') IS NULL
    ALTER TABLE dbo.stores ADD closed_at DATETIME2 NULL;
IF OBJECT_ID(N'dbo.stores') IS NOT NULL AND COL_LENGTH(N'dbo.stores', N'closure_reason') IS NULL
    ALTER TABLE dbo.stores ADD closure_reason NVARCHAR(500) NULL;

IF OBJECT_ID(N'dbo.user_schedules') IS NOT NULL AND COL_LENGTH(N'dbo.user_schedules', N'store_id') IS NULL
    ALTER TABLE dbo.user_schedules ADD store_id BIGINT NULL;
IF OBJECT_ID(N'dbo.user_schedules') IS NOT NULL AND COL_LENGTH(N'dbo.user_schedules', N'store_name') IS NULL
    ALTER TABLE dbo.user_schedules ADD store_name NVARCHAR(150) NULL;
IF OBJECT_ID(N'dbo.user_schedules') IS NOT NULL AND COL_LENGTH(N'dbo.user_schedules', N'store_code') IS NULL
    ALTER TABLE dbo.user_schedules ADD store_code VARCHAR(50) NULL;
IF OBJECT_ID(N'dbo.branch_requests') IS NOT NULL AND COL_LENGTH(N'dbo.branch_requests', N'store_id') IS NULL
    ALTER TABLE dbo.branch_requests ADD store_id BIGINT NULL;
IF OBJECT_ID(N'dbo.branch_requests') IS NOT NULL AND COL_LENGTH(N'dbo.branch_requests', N'store_name') IS NULL
    ALTER TABLE dbo.branch_requests ADD store_name NVARCHAR(150) NULL;
IF OBJECT_ID(N'dbo.branch_requests') IS NOT NULL AND COL_LENGTH(N'dbo.branch_requests', N'store_code') IS NULL
    ALTER TABLE dbo.branch_requests ADD store_code VARCHAR(50) NULL;

EXEC(N'IF OBJECT_ID(N''dbo.user_schedules'') IS NOT NULL
    UPDATE sc SET store_id = s.id, store_name = s.name, store_code = s.code
    FROM dbo.user_schedules sc JOIN dbo.users u ON u.id = sc.user_id JOIN dbo.stores s ON s.id = u.store_id
    WHERE sc.store_id IS NULL');
EXEC(N'IF OBJECT_ID(N''dbo.branch_requests'') IS NOT NULL
    UPDATE r SET store_id = s.id, store_name = s.name, store_code = s.code
    FROM dbo.branch_requests r JOIN dbo.users u ON u.id = r.user_id JOIN dbo.stores s ON s.id = u.store_id
    WHERE r.store_id IS NULL');

EXEC(N'IF OBJECT_ID(N''dbo.user_schedules'') IS NOT NULL AND EXISTS (
    SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.user_schedules'')
    AND CHARINDEX(N''[status]'', definition) > 0 AND CHARINDEX(N''CANCELLED'', definition) = 0)
BEGIN
    DECLARE @drop NVARCHAR(MAX) = N'''';
    SELECT @drop = @drop + N''ALTER TABLE dbo.user_schedules DROP CONSTRAINT '' + QUOTENAME(name) + N'';''
    FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.user_schedules'')
    AND CHARINDEX(N''[status]'', definition) > 0 AND CHARINDEX(N''CANCELLED'', definition) = 0;
    EXEC sp_executesql @drop;
    ALTER TABLE dbo.user_schedules ADD CONSTRAINT ck_branch_schedule_status CHECK ([status] IN (''PENDING'', ''CHECKED_IN'', ''CHECKED_OUT'', ''ABSENT'', ''ON_LEAVE'', ''CANCELLED''));
END');
