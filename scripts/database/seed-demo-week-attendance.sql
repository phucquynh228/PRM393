-- Explicit demo backfill: one shift per active staff/day, Monday-Wednesday,
-- then Thursday morning. Bind @WeekStart (date), @ThroughDate (date), @Apply (bit).
-- Preview never inserts rows or consumes identity values. Existing records are preserved.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

IF DB_NAME() <> 'CafeHRM' THROW 50001, 'This demo seed is restricted to CafeHRM.', 1;
IF DATEDIFF(day, '19000101', @WeekStart) % 7 <> 0 OR @ThroughDate <> DATEADD(day, 3, @WeekStart)
    THROW 50002, 'Choose Monday through Thursday morning of the same week.', 1;

DECLARE @Now datetime2 = CONVERT(datetime2, SYSDATETIMEOFFSET() AT TIME ZONE 'SE Asia Standard Time');
IF DATEADD(hour, 12, CONVERT(datetime2, @ThroughDate)) > @Now
    THROW 50003, 'Cannot create completed attendance for future shifts.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Templates TABLE (slot varchar(20) PRIMARY KEY, shift_id bigint, start_time time, end_time time);
    INSERT INTO @Templates
    SELECT v.slot, sh.id, sh.start_time, sh.end_time
    FROM (VALUES ('MORNING', '07:00', '12:00'), ('AFTERNOON', '12:00', '17:00'), ('EVENING', '17:00', '22:00')) v(slot, starts, ends)
    CROSS APPLY (SELECT TOP (1) id, start_time, end_time FROM dbo.shifts WITH (HOLDLOCK)
        WHERE active = 1 AND start_time = CONVERT(time, v.starts) AND end_time = CONVERT(time, v.ends) ORDER BY id) sh;
    IF (SELECT COUNT(*) FROM @Templates) <> 3
        THROW 50004, 'Expected active templates 07-12, 12-17 and 17-22.', 1;

    DECLARE @Plan TABLE (
        user_id bigint, store_id bigint, store_name nvarchar(150), store_code varchar(50),
        work_date date, shift_id bigint, slot varchar(20), starts datetime2, ends datetime2,
        check_in_time datetime2, check_out_time datetime2, skip_reason varchar(80),
        PRIMARY KEY (user_id, work_date)
    );
    ;WITH Staff AS (
        SELECT u.id, u.store_id, s.name AS store_name, s.code AS store_code,
            ROW_NUMBER() OVER (PARTITION BY u.store_id ORDER BY u.id) - 1 AS ordinal
        FROM dbo.users u WITH (UPDLOCK, HOLDLOCK) JOIN dbo.stores s WITH (HOLDLOCK) ON s.id = u.store_id
        WHERE u.role = 'STAFF' AND u.employment_status = 'ACTIVE' AND s.status = 'ACTIVE'
    )
    INSERT INTO @Plan (user_id, store_id, store_name, store_code, work_date, shift_id, slot, starts, ends, check_in_time, check_out_time)
    SELECT u.id, u.store_id, u.store_name, u.store_code, DATEADD(day, d.n, @WeekStart), t.shift_id, t.slot,
        times.starts, times.ends,
        DATEADD(minute, CASE (u.id + d.n) % 5 WHEN 1 THEN 4 WHEN 2 THEN 8 WHEN 3 THEN 12 ELSE 0 END, times.starts),
        DATEADD(minute, CASE WHEN (u.id + d.n) % 7 = 0 THEN -5 ELSE 0 END, times.ends)
    FROM Staff u CROSS JOIN (VALUES (0), (1), (2), (3)) d(n)
    OUTER APPLY (
        SELECT TOP (1) r.slot FROM dbo.user_fixed_roster r WITH (HOLDLOCK)
        JOIN @Templates rt ON rt.slot = r.slot
        WHERE r.user_id = u.id AND r.day_of_week = d.n + 1 ORDER BY rt.start_time
    ) roster
    JOIN @Templates t ON t.slot = CASE WHEN d.n = 3 THEN 'MORNING' ELSE COALESCE(roster.slot,
        CASE (u.ordinal + d.n) % 3 WHEN 0 THEN 'MORNING' WHEN 1 THEN 'AFTERNOON' ELSE 'EVENING' END) END
    CROSS APPLY (SELECT
        DATEADD(second, DATEDIFF(second, CONVERT(time, '00:00'), t.start_time), CONVERT(datetime2, DATEADD(day, d.n, @WeekStart))),
        DATEADD(second, DATEDIFF(second, CONVERT(time, '00:00'), t.end_time), CONVERT(datetime2, DATEADD(day, d.n, @WeekStart)))
    ) times(starts, ends);

    UPDATE p SET skip_reason = 'existing assignment or overlapping shift'
    FROM @Plan p WHERE EXISTS (
        SELECT 1 FROM dbo.user_schedules sc WITH (UPDLOCK, HOLDLOCK) JOIN dbo.shifts sh ON sh.id = sc.shift_id
        CROSS APPLY (SELECT
            DATEADD(second, DATEDIFF(second, CONVERT(time, '00:00'), sh.start_time), CONVERT(datetime2, sc.date)),
            DATEADD(second, DATEDIFF(second, CONVERT(time, '00:00'), sh.end_time), CONVERT(datetime2,
                DATEADD(day, CASE WHEN sh.end_time <= sh.start_time THEN 1 ELSE 0 END, sc.date)))
        ) old(starts, ends)
        WHERE sc.user_id = p.user_id AND sc.date BETWEEN DATEADD(day, -1, p.work_date) AND DATEADD(day, 1, p.work_date)
          AND ((sc.date = p.work_date AND (sc.shift_id = p.shift_id OR sc.shift_slot = p.slot))
            OR (sc.status NOT IN ('CANCELLED', 'ON_LEAVE') AND old.starts < p.ends AND p.starts < old.ends))
    );
    UPDATE p SET skip_reason = 'pending or approved leave'
    FROM @Plan p WHERE p.skip_reason IS NULL AND EXISTS (
        SELECT 1 FROM dbo.branch_requests r WITH (HOLDLOCK) WHERE r.user_id = p.user_id AND r.type = 'LEAVE'
          AND r.status IN ('PENDING', 'APPROVED') AND p.work_date BETWEEN r.start_date AND r.end_date
    );
    UPDATE p SET skip_reason = 'existing attendance overlaps proposed time'
    FROM @Plan p WHERE p.skip_reason IS NULL AND EXISTS (
        SELECT 1 FROM dbo.attendances a WITH (UPDLOCK, HOLDLOCK) WHERE a.user_id = p.user_id
          -- Invalid legacy intervals are excluded from worked time by AttendanceTiming.
          AND (a.check_out_time IS NULL OR (a.check_out_time > a.check_in_time
              AND a.check_out_time <= DATEADD(hour, 24, a.check_in_time)))
          AND a.check_in_time < p.check_out_time AND COALESCE(a.check_out_time, DATEADD(hour, 24, a.check_in_time)) > p.check_in_time
    );

    SELECT CASE WHEN @Apply = 1 THEN 'apply' ELSE 'preview' END AS mode,
        CONVERT(varchar(10), @WeekStart, 23) AS from_date, CONVERT(varchar(10), @ThroughDate, 23) AS through_morning,
        COUNT(DISTINCT user_id) AS staff_count, COUNT(*) AS planned, SUM(CASE WHEN skip_reason IS NULL THEN 1 ELSE 0 END) AS eligible,
        SUM(CASE WHEN skip_reason IS NOT NULL THEN 1 ELSE 0 END) AS skipped FROM @Plan;
    SELECT store_code, CONVERT(varchar(10), work_date, 23) AS work_date, slot, COUNT(*) AS eligible_shifts
        FROM @Plan WHERE skip_reason IS NULL GROUP BY store_code, work_date, slot ORDER BY store_code, work_date, slot;
    SELECT user_id, CONVERT(varchar(10), work_date, 23) AS work_date, slot, skip_reason
        FROM @Plan WHERE skip_reason IS NOT NULL ORDER BY user_id, work_date;

    DECLARE @Created TABLE (schedule_id bigint PRIMARY KEY, user_id bigint, work_date date);
    DECLARE @Attendance TABLE (attendance_id bigint PRIMARY KEY, schedule_id bigint);
    IF @Apply = 1
    BEGIN
        INSERT INTO dbo.user_schedules (user_id, store_id, store_name, store_code, shift_id, date, status, shift_slot, published, temporary_transfer)
        OUTPUT inserted.id, inserted.user_id, inserted.date INTO @Created
        SELECT user_id, store_id, store_name, store_code, shift_id, work_date, 'CHECKED_OUT', slot, 1, 0
        FROM @Plan WHERE skip_reason IS NULL;

        -- These are explicit manual demo records, not claims of real GPS check-ins.
        INSERT INTO dbo.attendances (user_id, schedule_id, check_in_time, check_out_time, check_in_lat, check_in_lng, manually_adjusted)
        OUTPUT inserted.id, inserted.schedule_id INTO @Attendance
        SELECT c.user_id, c.schedule_id, p.check_in_time, p.check_out_time, NULL, NULL, 1
        FROM @Created c JOIN @Plan p ON p.user_id = c.user_id AND p.work_date = c.work_date;

        IF (SELECT COUNT(*) FROM @Created) <> (SELECT COUNT(*) FROM @Attendance)
            THROW 50005, 'Attendance count does not match newly created shifts.', 1;
        IF EXISTS (SELECT 1 FROM @Attendance x JOIN dbo.attendances a ON a.id = x.attendance_id
            JOIN dbo.user_schedules sc ON sc.id = x.schedule_id
            WHERE a.user_id <> sc.user_id OR a.check_out_time <= a.check_in_time
                OR DATEDIFF(minute, a.check_in_time, a.check_out_time) > 1440 OR a.check_out_time > @Now
                OR sc.status <> 'CHECKED_OUT' OR sc.published <> 1)
            THROW 50006, 'Generated attendance failed validation.', 1;
    END;

    SELECT (SELECT COUNT(*) FROM @Created) AS created_schedules, (SELECT COUNT(*) FROM @Attendance) AS created_attendances;
    SELECT c.schedule_id, a.attendance_id, c.user_id, CONVERT(varchar(10), c.work_date, 23) AS work_date
        FROM @Created c JOIN @Attendance a ON a.schedule_id = c.schedule_id ORDER BY c.user_id, c.work_date;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
