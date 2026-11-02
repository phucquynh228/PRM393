-- Changing varchar to nvarchar prevents future data loss, but cannot recover
-- characters already stored as '?'. Restore only known damaged seed names.
-- Exact binary comparisons and original seed locations/times preserve custom
-- names, branch codes, assignments, and all other operational data.

IF OBJECT_ID(N'dbo.stores', N'U') IS NOT NULL
    UPDATE dbo.stores SET name = N'Cafe Thủ Đức'
    WHERE name COLLATE Latin1_General_100_BIN2 IN (N'Cafe Th? Ð?c', N'Cafe Th? Đ?c')
        AND latitude = 10.8512 AND longitude = 106.7718;

IF OBJECT_ID(N'dbo.stores', N'U') IS NOT NULL
    UPDATE dbo.stores SET name = N'Cafe Quận 1'
    WHERE name COLLATE Latin1_General_100_BIN2 = N'Cafe Qu?n 1'
        AND latitude = 10.7769 AND longitude = 106.7009;

IF OBJECT_ID(N'dbo.stores', N'U') IS NOT NULL
    UPDATE dbo.stores SET name = N'Cafe Bình Thạnh'
    WHERE name COLLATE Latin1_General_100_BIN2 = N'Cafe Bình Th?nh'
        AND latitude = 10.8013 AND longitude = 106.7100;

IF OBJECT_ID(N'dbo.shifts', N'U') IS NOT NULL
    UPDATE dbo.shifts SET name = N'Ca Chiều'
    WHERE name COLLATE Latin1_General_100_BIN2 = N'Ca Chi?u'
        AND start_time = '12:00:00' AND end_time = '17:00:00';

IF OBJECT_ID(N'dbo.shifts', N'U') IS NOT NULL
    UPDATE dbo.shifts SET name = N'Ca Tối'
    WHERE name COLLATE Latin1_General_100_BIN2 = N'Ca T?i'
        AND start_time = '17:00:00' AND end_time = '22:00:00';
