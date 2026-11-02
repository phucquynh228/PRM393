-- Demo accounts for CafeHRM. Password: 123456 (BCrypt).
-- Safe to rerun: existing accounts are preserved and phone numbers are unique.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @seed TABLE (
        store_code VARCHAR(50) NOT NULL,
        name NVARCHAR(100) NOT NULL,
        phone VARCHAR(15) NOT NULL PRIMARY KEY
    );
    INSERT INTO @seed (store_code, name, phone) VALUES
        ('CN-01', N'Nguyễn Minh Anh', '0902000101'),
        ('CN-01', N'Trần Hoàng Nam', '0902000102'),
        ('CN-01', N'Lê Thảo Nguyên', '0902000103'),
        ('CN-01', N'Phạm Quốc Bảo', '0902000104'),
        ('CN-01', N'Võ Ngọc Hân', '0902000105'),
        ('CN-02', N'Đặng Gia Huy', '0902000201'),
        ('CN-02', N'Bùi Khánh Linh', '0902000202'),
        ('CN-02', N'Đỗ Tuấn Kiệt', '0902000203'),
        ('CN-02', N'Hồ Mai Phương', '0902000204'),
        ('CN-02', N'Dương Đức Anh', '0902000205'),
        ('CN-03', N'Nguyễn Hải Đăng', '0902000301'),
        ('CN-03', N'Trần Bảo Trân', '0902000302'),
        ('CN-03', N'Lê Thanh Tùng', '0902000303'),
        ('CN-03', N'Phạm Yến Nhi', '0902000304'),
        ('CN-03', N'Vũ Minh Khang', '0902000305'),
        ('HN-01', N'Nguyễn Hà My', '0902002201'),
        ('HN-01', N'Trần Việt Hoàng', '0902002202'),
        ('HN-01', N'Lê Phương Anh', '0902002203'),
        ('HN-01', N'Phạm Trung Hiếu', '0902002204'),
        ('HN-01', N'Đỗ Thu Trang', '0902002205');

    DECLARE @branch_count INT;
    SELECT @branch_count = COUNT(*) FROM dbo.stores WITH (UPDLOCK, HOLDLOCK)
    WHERE code IN (SELECT store_code FROM @seed) AND status = 'ACTIVE';
    IF @branch_count <> 4
        THROW 50001, N'Cần đúng 4 chi nhánh đang hoạt động: CN-01, CN-02, CN-03, HN-01.', 1;

    IF EXISTS (
        SELECT s.code FROM dbo.stores s
        WHERE s.code IN (SELECT store_code FROM @seed)
        GROUP BY s.code HAVING COUNT(*) <> 1
    )
        THROW 50002, N'Mã chi nhánh không duy nhất; cần kiểm tra trước khi thêm dữ liệu mẫu.', 1;

    IF EXISTS (
        SELECT 1 FROM @seed d
        JOIN dbo.stores s ON s.code = d.store_code
        JOIN dbo.users u WITH (UPDLOCK, HOLDLOCK) ON u.phone = d.phone
        WHERE u.role <> 'STAFF' OR u.store_id IS NULL OR u.store_id <> s.id
    )
        THROW 50003, N'Số điện thoại mẫu đang thuộc một tài khoản khác. Không thay đổi tài khoản hiện có.', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.stores s
        WHERE s.code IN (SELECT store_code FROM @seed)
          AND (SELECT COUNT(*) FROM dbo.users u WITH (UPDLOCK, HOLDLOCK) WHERE u.store_id = s.id)
            + (SELECT COUNT(*) FROM @seed d WHERE d.store_code = s.code
                AND NOT EXISTS (SELECT 1 FROM dbo.users u WHERE u.phone = d.phone)) > ISNULL(s.max_staff, 15)
    )
        THROW 50004, N'Thêm dữ liệu mẫu sẽ vượt định biên chi nhánh.', 1;

    DECLARE @created TABLE (id BIGINT, name NVARCHAR(100), phone VARCHAR(15), store_id BIGINT);
    INSERT INTO dbo.users (name, phone, password, role, device_id, store_id, email)
    OUTPUT inserted.id, inserted.name, inserted.phone, inserted.store_id INTO @created
    SELECT d.name, d.phone,
        '$2a$10$Lc7DcmvFirB6nq2tAmac.ugVOGLFjnOeoO5RD5TM4dXTw0lUOfEBC',
        'STAFF', NULL, s.id, CONCAT('staff.', d.phone, '@hrm.test')
    FROM @seed d
    JOIN dbo.stores s ON s.code = d.store_code
    WHERE NOT EXISTS (SELECT 1 FROM dbo.users u WITH (UPDLOCK, HOLDLOCK) WHERE u.phone = d.phone);

    COMMIT TRANSACTION;

    SELECT c.id, c.name, c.phone, s.code AS store_code, s.name AS store_name
    FROM @created c JOIN dbo.stores s ON s.id = c.store_id ORDER BY s.id, c.phone;

    SELECT s.code, s.name, s.max_staff,
        COUNT(u.id) AS total_accounts,
        SUM(CASE WHEN u.role = 'STAFF' THEN 1 ELSE 0 END) AS staff_count
    FROM dbo.stores s LEFT JOIN dbo.users u ON u.store_id = s.id
    WHERE s.code IN (SELECT store_code FROM @seed)
    GROUP BY s.id, s.code, s.name, s.max_staff ORDER BY s.id;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
