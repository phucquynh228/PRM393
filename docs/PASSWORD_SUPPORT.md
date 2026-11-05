# Quên mật khẩu — Admin hỗ trợ trực tiếp

Email và SĐT trong dữ liệu mẫu chưa được xác minh. SĐT là định danh đăng nhập, không phải bằng chứng sở hữu tài khoản. Luồng này không phụ thuộc email/SMS/OTP.

Admin, Manager và Staff còn nhớ mật khẩu hiện tại đều **tự đổi mật khẩu** tại **Profile → Tài khoản và bảo mật → Đổi mật khẩu**. Chỉ dùng luồng hỗ trợ bên dưới khi quên mật khẩu. Manager/Staff cũng có nút **Yêu cầu Admin hỗ trợ** trong phần **Quên mật khẩu?** của Profile, tự điền SĐT đăng nhập.

Manager không được đổi hoặc đặt lại mật khẩu của nhân viên. Form sửa nhân viên không có trường mật khẩu và `PUT /api/manager/staff/{id}` từ chối yêu cầu có `password`. Mật khẩu ban đầu khi tạo nhân viên mới vẫn được thiết lập trong luồng tạo tài khoản.

## Luồng sử dụng

1. Từ màn hình đăng nhập, chọn **Quên mật khẩu?** → nhập SĐT đăng nhập, họ tên và ghi chú → **Gửi yêu cầu hỗ trợ**.
2. Staff hoặc Manager gặp trực tiếp Admin để xác minh danh tính với hồ sơ nhân sự. Thông tin tự khai trên form chỉ để tham khảo.
3. Admin mở **Profile → Quản lý tài khoản → Hỗ trợ mật khẩu → Chờ xử lý**. Chọn **Đặt lại mật khẩu**, xác nhận đã đối chiếu danh tính, nhập mật khẩu mới và xác nhận; hoặc **Từ chối** kèm lý do.
4. Admin trao mật khẩu trực tiếp cho đúng nhân viên đã xác minh. Người dùng đăng nhập lại bằng mật khẩu mới. Các JWT phát hành trước khi đặt lại hết hiệu lực.

Mật khẩu mới có ít nhất 8 ký tự, tối đa 72 byte UTF-8 và khác mật khẩu cũ. Backend lưu BCrypt; mật khẩu mới không xuất hiện trong phản hồi hay lịch sử yêu cầu. Device binding, vai trò và liên kết Google không thay đổi.

## API

| Endpoint | Quyền | Nội dung |
|---|---|---|
| `POST /api/auth/password-support` | Công khai | `{phone, name, note?}` → HTTP 202, thông báo chung, `data: null` |
| `GET /api/admin/password-support?status=PENDING` | Admin | Tối đa 100 yêu cầu gần nhất; hỗ trợ `PENDING`, `RESOLVED`, `REJECTED` |
| `PUT /api/admin/password-support/{id}` | Admin | `{action: "RESOLVE", identityVerified: true, newPassword, adminNote?}` hoặc `{action: "REJECT", adminNote}` |

Phản hồi công khai giống nhau cho SĐT không tồn tại, tài khoản Admin, yêu cầu trùng và yêu cầu hợp lệ. Không cung cấp API công khai xem trạng thái hoặc lấy mật khẩu. Tài khoản Admin được khôi phục qua quản trị hệ thống ngoài luồng này.

Mỗi tài khoản chỉ có một yêu cầu chờ xử lý; gửi lặp không ghi đè thông tin ban đầu. Yêu cầu mới cách yêu cầu gần nhất tối thiểu 5 phút. Khóa giao dịch theo tài khoản/yêu cầu giúp xử lý nhất quán khi gửi hoặc xử lý đồng thời; yêu cầu đã xử lý không được dùng lại.

## Dữ liệu và chạy ứng dụng

JPA `ddl-auto: update` tạo bảng `password_support_requests` và bổ sung `users.credentials_version` (BIGINT, NOT NULL, mặc định 0) khi backend khởi động. Các trường chính của bảng:

| Trường | Ý nghĩa |
|---|---|
| `id`, `user_id` | Yêu cầu và tài khoản liên quan |
| `requested_name`, `note` | Thông tin người gửi tự khai, NVARCHAR(100)/NVARCHAR(500) |
| `status`, `created_at` | Trạng thái và thời điểm gửi |
| `handled_by`, `handled_at`, `admin_note` | Admin xử lý, thời điểm và ghi chú; không lưu mật khẩu |

JWT mới chứa `credentialsVersion`. Token cũ không có claim này được coi là phiên bản 0; Admin đặt lại mật khẩu sẽ tăng phiên bản của tài khoản, vô hiệu hóa các JWT trước đó. Tài khoản có lịch sử gửi hoặc xử lý hỗ trợ không được xóa cứng; sử dụng ngừng hoạt động để giữ lịch sử.

Khởi động lại backend để nạp API/schema mới, rồi hot restart hoặc build lại Flutter. Nếu app đang đăng nhập bằng phiên cũ, đăng nhập lại sau khi Admin đặt lại mật khẩu.

## Kiểm tra

```powershell
.\mvnw.cmd test '-Dtest=PasswordSupportServiceTest,PasswordSupportControllerTest,PasswordResetSessionTest'
# SQL Server: dữ liệu kiểm thử tự rollback.
.\mvnw.cmd test '-Dtest=PasswordSupportIntegrationTest' '-Dpassword.integration=true'
cd hrm_app
flutter test --no-pub test/features/auth/password_support_test.dart
flutter analyze --no-pub
```
