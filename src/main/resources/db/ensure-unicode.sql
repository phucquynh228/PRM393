-- Hibernate schema update may treat varchar and nvarchar as equivalent.
-- Upgrade only existing legacy columns; fresh databases are created by JPA.
-- Keep column lengths and nullability consistent with the entity mappings.
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.users') AND name = N'name' AND TYPE_NAME(system_type_id) = N'varchar')
    ALTER TABLE dbo.users ALTER COLUMN name NVARCHAR(100) NOT NULL;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.stores') AND name = N'name' AND TYPE_NAME(system_type_id) = N'varchar')
    ALTER TABLE dbo.stores ALTER COLUMN name NVARCHAR(150) NOT NULL;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.shifts') AND name = N'name' AND TYPE_NAME(system_type_id) = N'varchar')
    ALTER TABLE dbo.shifts ALTER COLUMN name NVARCHAR(100) NOT NULL;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.system_configs') AND name = N'config_value' AND TYPE_NAME(system_type_id) = N'varchar')
    ALTER TABLE dbo.system_configs ALTER COLUMN config_value NVARCHAR(500) NOT NULL;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.branch_requests') AND name = N'reason' AND TYPE_NAME(system_type_id) = N'varchar')
    ALTER TABLE dbo.branch_requests ALTER COLUMN reason NVARCHAR(1000) NOT NULL;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.branch_requests') AND name = N'manager_note' AND TYPE_NAME(system_type_id) = N'varchar')
    ALTER TABLE dbo.branch_requests ALTER COLUMN manager_note NVARCHAR(1000) NULL;

-- Attendance corrections can create an approved record without a GPS capture.
-- Such records are explicitly marked manually_adjusted by the service.
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.attendances') AND name = N'check_in_lat' AND is_nullable = 0)
    ALTER TABLE dbo.attendances ALTER COLUMN check_in_lat FLOAT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.attendances') AND name = N'check_in_lng' AND is_nullable = 0)
    ALTER TABLE dbo.attendances ALTER COLUMN check_in_lng FLOAT NULL;

-- SQL Server keeps old enum CHECK constraints when Hibernate adds enum values.
-- Each batch replaces only the legacy enum check, once, without deleting rows.
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.branch_requests') AND name = N'type' AND max_length < 30)
    ALTER TABLE dbo.branch_requests ALTER COLUMN type VARCHAR(30) NOT NULL;

EXEC(N'IF OBJECT_ID(N''dbo.branch_requests'') IS NOT NULL AND EXISTS (
    SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.branch_requests'')
    AND CHARINDEX(N''[type]'', definition) > 0 AND CHARINDEX(N''ATTENDANCE_CORRECTION'', definition) = 0)
BEGIN
    DECLARE @drop NVARCHAR(MAX) = N'''';
    SELECT @drop = @drop + N''ALTER TABLE dbo.branch_requests DROP CONSTRAINT '' + QUOTENAME(name) + N'';''
    FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.branch_requests'')
    AND CHARINDEX(N''[type]'', definition) > 0 AND CHARINDEX(N''ATTENDANCE_CORRECTION'', definition) = 0;
    EXEC sp_executesql @drop;
    ALTER TABLE dbo.branch_requests ADD CONSTRAINT ck_staff_request_type CHECK ([type] IN (''LEAVE'', ''UNPAID_LEAVE'', ''SHIFT_SWAP'', ''ATTENDANCE_CORRECTION''));
END');

EXEC(N'IF OBJECT_ID(N''dbo.branch_requests'') IS NOT NULL AND EXISTS (
    SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.branch_requests'')
    AND CHARINDEX(N''[status]'', definition) > 0 AND CHARINDEX(N''CANCELLED'', definition) = 0)
BEGIN
    DECLARE @drop NVARCHAR(MAX) = N'''';
    SELECT @drop = @drop + N''ALTER TABLE dbo.branch_requests DROP CONSTRAINT '' + QUOTENAME(name) + N'';''
    FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.branch_requests'')
    AND CHARINDEX(N''[status]'', definition) > 0 AND CHARINDEX(N''CANCELLED'', definition) = 0;
    EXEC sp_executesql @drop;
    ALTER TABLE dbo.branch_requests ADD CONSTRAINT ck_staff_request_status CHECK ([status] IN (''PENDING'', ''APPROVED'', ''REJECTED'', ''CANCELLED''));
END');

EXEC(N'IF OBJECT_ID(N''dbo.user_schedules'') IS NOT NULL AND EXISTS (
    SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.user_schedules'')
    AND CHARINDEX(N''[status]'', definition) > 0 AND CHARINDEX(N''ON_LEAVE'', definition) = 0)
BEGIN
    DECLARE @drop NVARCHAR(MAX) = N'''';
    SELECT @drop = @drop + N''ALTER TABLE dbo.user_schedules DROP CONSTRAINT '' + QUOTENAME(name) + N'';''
    FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.user_schedules'')
    AND CHARINDEX(N''[status]'', definition) > 0 AND CHARINDEX(N''ON_LEAVE'', definition) = 0;
    EXEC sp_executesql @drop;
    ALTER TABLE dbo.user_schedules ADD CONSTRAINT ck_staff_schedule_status CHECK ([status] IN (''PENDING'', ''CHECKED_IN'', ''CHECKED_OUT'', ''ABSENT'', ''ON_LEAVE''));
END');
