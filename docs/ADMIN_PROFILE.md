# Hồ sơ & quản trị của Admin

Thanh điều hướng chính gồm **Tổng quan, Chi nhánh, Chấm công, Lịch làm**. Mở icon hồ sơ ở thanh tiêu đề hoặc nút **Hồ sơ & quản trị** trên Tổng quan để vào khu vực tài khoản và thiết lập.

## Các mục trong Profile

1. **Thông tin cá nhân**: sửa họ tên, email, địa chỉ của Admin đang đăng nhập. SĐT đăng nhập và vai trò được giữ nguyên.
2. **Tài khoản và bảo mật**: xem SĐT đăng nhập, trạng thái liên kết thiết bị/Google; đổi mật khẩu bằng mật khẩu hiện tại. Mật khẩu mới từ 8 ký tự, tối đa 72 byte UTF-8. Đổi thành công sẽ vô hiệu hóa phiên cũ và trở về đăng nhập.
3. **Phân quyền hệ thống**: xem phạm vi quyền của Admin, Manager, Staff; số tài khoản theo từng vai trò. Nút xem tài khoản mở Quản lý tài khoản với bộ lọc vai trò tương ứng. Phân quyền tiếp tục theo vai trò và chi nhánh đang áp dụng trên backend.
4. **Quản lý tài khoản**: danh sách tài khoản đã chuyển khỏi thanh điều hướng chính; giữ tìm kiếm, lọc vai trò/chi nhánh, tạo tài khoản, đặt lại thiết bị, điều chuyển/trạng thái và hỗ trợ mật khẩu.
5. **Cấu hình hệ thống**: sửa thời gian nhắc trước ca (1–120 phút), lưu vào `system_configs.reminder_minutes` mà job nhắc ca đang đọc. Hiển thị múi giờ Việt Nam và giới hạn check-out; mở cấu hình mẫu ca hoặc chi nhánh từ đây.

## API mới, chỉ dành cho Admin

| API | Chức năng |
|---|---|
| `GET /api/admin/profile` | Hồ sơ của tài khoản đang xác thực; không trả mật khẩu hoặc token |
| `PUT /api/admin/profile` | `{name, email, address}`; cập nhật hồ sơ cá nhân |
| `PUT /api/admin/profile/password` | `{currentPassword, newPassword}`; kiểm tra mật khẩu cũ, mã hóa BCrypt và tăng phiên bản thông tin xác thực |
| `GET /api/admin/settings` | Thời gian nhắc ca, múi giờ và giới hạn check-out |
| `PUT /api/admin/settings` | `{reminderMinutes}`; kiểm tra giới hạn và lưu cấu hình |

Thông tin cá nhân lấy theo danh tính đã xác thực, không nhận ID tài khoản đích từ client. Nhân viên và quản lý chi nhánh không có quyền truy cập các API này.

## Kiểm tra

```powershell
.\mvnw.cmd test '-Dtest=AdminProfileControllerTest,AdminProfileIntegrationTest' '-Dadmin.profile.integration=true'
cd hrm_app
flutter test --no-pub test/features/admin/admin_profile_test.dart
flutter analyze --no-pub
```

Test SQL Server dùng tài khoản kiểm thử riêng và rollback toàn bộ dữ liệu thay đổi sau khi chạy.

## Profile của Manager và Staff

Các role dùng cùng kiểu thẻ nhận diện (họ tên, SĐT, vai trò) và danh sách mục có icon. Manager mở bằng icon hồ sơ trên thanh tiêu đề; Staff mở bằng icon này hoặc mục **Hồ sơ** trong điều hướng.

- **Thông tin cá nhân**: xem và sửa họ tên, email, địa chỉ, số liên hệ khẩn cấp. Lưu thành công sẽ cập nhật lại thông tin hiển thị.
- **Tài khoản và bảo mật**: xem mã tài khoản và SĐT đăng nhập; đổi mật khẩu bằng mật khẩu hiện tại. Giữ chính sách hiện tại của tài khoản nhân sự: tối thiểu 6 ký tự, tối đa 72 byte UTF-8. Quên mật khẩu hoặc cần đổi SĐT phải yêu cầu Admin hỗ trợ; không gửi OTP/email đến thông tin chưa xác minh.
- **Thông tin công việc**: xem mã nhân viên, chi nhánh, trạng thái làm việc và ca mặc định; không tự sửa chức vụ, chi nhánh hoặc ca mặc định.
- **Đăng xuất**: dùng luồng xác nhận và xóa phiên hiện có.

Các mục phân quyền, quản lý tài khoản và cấu hình hệ thống thuộc Profile Admin. Manager và Staff chỉ gọi API hồ sơ đúng vai trò của mình.

Manager có `GET /api/manager/profile`, `PUT /api/manager/profile` và `PUT /api/manager/password`. Danh tính lấy từ phiên xác thực; client không chọn tài khoản đích, không đổi được vai trò, SĐT hay chi nhánh qua API hồ sơ. Manager chưa được gán chi nhánh vẫn xem và sửa hồ sơ của mình được. Staff tiếp tục dùng `/api/staff/workspace`, `/api/staff/profile` và `/api/staff/password`.

```powershell
.\mvnw.cmd test '-Dtest=ManagerProfileControllerTest,ManagerProfileIntegrationTest' '-Dstaff.integration=true'
cd hrm_app
flutter test --no-pub test/features/admin/admin_profile_test.dart test/features/branch/manager_profile_test.dart test/features/staff/staff_test.dart
```
