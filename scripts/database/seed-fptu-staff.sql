-- Five demo staff for the existing Cafe FPTU branch. Password: 123456 (BCrypt).
-- Run explicitly against CafeHRM. Existing accounts are never overwritten.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @store_id BIGINT, @max_staff INT;
    SELECT @store_id = id, @max_staff = ISNULL(max_staff, 15)
    FROM dbo.stores WITH (UPDLOCK, HOLDLOCK)
    WHERE code = 'HN-02' AND name = N'Cafe FPTU' AND status = 'ACTIVE';
    IF @store_id IS NULL
        THROW 50001, N'Không tìm thấy Cafe FPTU (HN-02) đang hoạt động.', 1;

    DECLARE @seed TABLE (name NVARCHAR(100), phone VARCHAR(15) PRIMARY KEY);
    INSERT INTO @seed (name, phone) VALUES
        (N'Nguyễn Đức Huy', '0902002301'),
        (N'Trần Ngọc Mai', '0902002302'),
        (N'Lê Minh Khoa', '0902002303'),
        (N'Phạm Thu Hà', '0902002304'),
        (N'Võ Gia Bảo', '0902002305');

    IF EXISTS (
        SELECT 1 FROM @seed d JOIN dbo.users u WITH (UPDLOCK, HOLDLOCK) ON u.phone = d.phone
        WHERE u.role <> 'STAFF' OR u.store_id IS NULL OR u.store_id <> @store_id
            OR u.employment_status <> 'ACTIVE'
    )
        THROW 50002, N'Số điện thoại mẫu đã thuộc tài khoản khác hoặc đã ngừng làm việc. Không thay đổi tài khoản cũ.', 1;

    DECLARE @current INT = (SELECT COUNT(*) FROM dbo.users WITH (UPDLOCK, HOLDLOCK) WHERE store_id = @store_id);
    DECLARE @new INT = (SELECT COUNT(*) FROM @seed d WHERE NOT EXISTS (SELECT 1 FROM dbo.users u WITH (UPDLOCK, HOLDLOCK) WHERE u.phone = d.phone));
    IF @current + @new > @max_staff
        THROW 50003, N'Không đủ định biên tại Cafe FPTU để thêm nhóm nhân viên mẫu.', 1;

    INSERT INTO dbo.users (name, phone, password, role, device_id, store_id, email, employment_status)
    SELECT d.name, d.phone,
        '$2a$10$Lc7DcmvFirB6nq2tAmac.ugVOGLFjnOeoO5RD5TM4dXTw0lUOfEBC',
        'STAFF', NULL, @store_id, CONCAT('staff.', d.phone, '@hrm.test'), 'ACTIVE'
    FROM @seed d
    WHERE NOT EXISTS (SELECT 1 FROM dbo.users u WITH (UPDLOCK, HOLDLOCK) WHERE u.phone = d.phone);

    DECLARE @created INT = @@ROWCOUNT;
    COMMIT TRANSACTION;

    SELECT @created AS created_accounts;
    SELECT u.id, u.name, u.phone, u.role, u.employment_status, s.code AS store_code, s.name AS store_name
    FROM dbo.users u JOIN @seed d ON d.phone = u.phone JOIN dbo.stores s ON s.id = u.store_id ORDER BY u.phone;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
