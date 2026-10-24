# Dữ liệu database

- `backups/hrm_appdata.sql`: bản xuất SQL Server của project, lưu tách khỏi mã ứng dụng.
- `../src/main/resources/db/`: script nâng cấp schema/dữ liệu cũ, được Spring Boot gọi theo `application.yml`.
- `../scripts/database/seed-demo-staff.sql`: thêm 20 tài khoản Staff mẫu vào 4 chi nhánh hiện có; kiểm tra mã chi nhánh, định biên và số điện thoại. Chạy lại không thêm trùng và không ghi đè tài khoản cũ.

Tài khoản nhân viên mẫu dùng mật khẩu `123456` đã mã hóa BCrypt:

| Chi nhánh | Số điện thoại |
|---|---|
| CN-01 – Cafe Thủ Đức | 0902000101–0902000105 |
| CN-02 – Cafe Quận 1 | 0902000201–0902000205 |
| CN-03 – Cafe Bình Thạnh | 0902000301–0902000305 |
| HN-01 – Cầu Giấy | 0902002201–0902002205 |

Script demo chạy chủ động trên database `CafeHRM`, không tự chạy mỗi lần mở app. Cấu trúc thư mục mới không đổi tên bảng hoặc dữ liệu tài khoản.
