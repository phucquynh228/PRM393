# Chức năng Staff

Đăng nhập bằng tài khoản có vai trò `STAFF` để mở không gian nhân viên mới.
Tài khoản mẫu: `0901000003` / `123456` (nếu chưa đổi mật khẩu).

## Các màn hình

1. **Trang chủ**: ca hôm nay, chi nhánh, trạng thái ca, check-in/check-out, tổng giờ thực tế và giờ được phân công của tuần hiện tại, thông báo và yêu cầu gần đây.
2. **Chấm công**: vào/ra ca bằng API hiện có, lịch sử, khoảng ngày, bộ lọc đi muộn/về sớm/chưa ra ca, thời lượng thực tế và yêu cầu sửa công.
3. **Lịch làm**: xem theo tuần hoặc tháng, chọn ngày trên thanh thứ Hai–Chủ nhật, xem số ca mỗi ngày hoặc cả tuần. Ca sắp tới hiển thị trước; thẻ ca có giờ, chi nhánh, thời gian nghỉ và ghi chú qua đêm. Xem chi tiết, đề nghị đổi ca hoặc dùng nút cuối danh sách để gửi yêu cầu đổi ca/xin nghỉ. Chỉ lịch đã công bố mới xuất hiện.
4. **Yêu cầu**: nghỉ phép, nghỉ không lương, đổi ca, điều chỉnh chấm công; lọc theo loại/trạng thái; xem ghi chú quản lý và hủy đơn còn hợp lệ.
5. **Thông báo**: phân công/thay đổi/hủy lịch, nhắc giờ vào ca, kết quả duyệt đơn và thông báo từ quản lý; đánh dấu đã đọc từng thông báo hoặc tất cả.
6. **Hồ sơ**: mã nhân viên dạng `NV-xxxx`, tên, số điện thoại, chức vụ, chi nhánh, email, liên hệ khẩn cấp, địa chỉ; cập nhật thông tin cá nhân, đổi mật khẩu và đăng xuất.

Điện thoại hiển thị bốn mục đầu và menu **Thêm** cho Thông báo/Hồ sơ. Màn hình rộng hiển thị cả sáu mục ở thanh bên.

## Quy tắc nghiệp vụ

- Giờ công tuần tính từ thứ Hai, chỉ cộng khoảng thời gian đã check-out, cắt đúng ranh giới tuần kể cả ca qua nửa đêm. Giờ đang làm chưa được cộng vào tổng đã hoàn tất.
- Đi muộn/về sớm so sánh giờ thực tế với giờ bắt đầu/kết thúc ca, hiển thị theo phút nguyên. Hiện chưa áp dụng thời gian ân hạn.
- Check-in xác thực vị trí bằng GPS với phạm vi chi nhánh, chỉ áp dụng ca hôm nay hoặc ca đêm hôm trước còn hiệu lực. Không thể check-in ca đã nghỉ phép/đã chấm công.
- Mỗi đơn nghỉ tối đa 31 ngày, không gửi cho ca đã bắt đầu hoặc đã chấm công. Khi duyệt, các ca đã công bố trong khoảng nghỉ chuyển sang `ON_LEAVE`; quản lý không thể phân/công bố ca mới vào ngày đã duyệt nghỉ.
- Đổi ca chọn ca của mình và ca của một nhân viên khác cùng chi nhánh. Hai ca phải đã công bố, chưa bắt đầu và chưa chấm công. Khi duyệt, backend kiểm tra lại ca, người nhận, ngày, trùng lịch và lịch nghỉ rồi hoán đổi người được phân công.
- Sửa công áp dụng cho ca trong 30 ngày gần đây. Cần giờ vào và ra đề xuất hợp lệ, không ở tương lai, thời lượng tối đa 24 giờ. Khi duyệt, backend cập nhật/tạo bản ghi, kiểm tra trùng giờ và đánh dấu `manuallyAdjusted`. Bản ghi sửa thủ công không tạo tọa độ GPS giả.
- Chỉ quản lý cùng chi nhánh được duyệt/từ chối. Từ chối bắt buộc có lý do. Chỉ chủ đơn được hủy; đơn đã xử lý không được hủy/duyệt lần nữa.
- Nhân viên được sửa tên, email, địa chỉ và liên hệ khẩn cấp. Số điện thoại đăng nhập, vai trò và chi nhánh do quản lý quản lý. Đổi mật khẩu phải xác nhận mật khẩu hiện tại.
- Thông báo lưu trong cơ sở dữ liệu và hiển thị 100 thông báo gần nhất. App làm mới khi quay lại foreground, mỗi phút khi đang mở, hoặc bằng nút làm mới. Nhắc ca chạy mỗi phút trên backend theo múi giờ Việt Nam và chống gửi trùng. Chưa tích hợp push Firebase khi ứng dụng đóng.
- Quản lý gửi thông báo ở **Yêu cầu → Gửi thông báo**. Duyệt đơn tự cập nhật lịch/công và tạo thông báo, không cần chỉnh lại bằng tay.

## API và mã nguồn

### Phân quyền và quản lý lịch

- **Admin → Lịch làm → Lịch chi nhánh**: xem lịch nháp và đã công bố của toàn chuỗi theo tuần, lọc chi nhánh. Không trực tiếp phân công nhân viên.
- **Admin → Lịch làm → Mẫu ca**: tạo/sửa tên, giờ bắt đầu/kết thúc, số phút nghỉ; bật/tắt cho phép sử dụng. Mẫu dùng chung toàn chuỗi. Không xóa mẫu có lịch sử; khi sửa nội dung mẫu đã được sử dụng, hệ thống ngừng mẫu cũ và tạo phiên bản mới để giữ nguyên giờ của các lịch đã tạo. Nháp dùng mẫu cũ cần chọn lại mẫu đang hoạt động trước khi công bố.
- **Manager → Lịch làm**: xem ngày/tuần/tháng, lọc nháp/đã công bố, chọn ngày trong tuần, xem mẫu ca đang hoạt động, phân công từng ca và công bố toàn bộ ca nháp trong khoảng đang xem. Nếu một ca không hợp lệ, toàn bộ thao tác công bố bị từ chối và giữ nguyên nháp.
- Chỉ Manager cùng chi nhánh được phân ca. Backend kiểm tra chồng giờ trên tất cả lịch, gồm nháp và ca qua đêm; hai ca sát giờ kết thúc/bắt đầu được phép. Ca `ON_LEAVE` không gây trùng giờ, nhưng ngày đã duyệt nghỉ vẫn bị chặn phân ca.
- Không phân/công bố ca đã bắt đầu, mẫu đã ngừng sử dụng hoặc nhân viên không hợp lệ. Không sửa/xóa ca đã bắt đầu hoặc đã chấm công. Khi sửa, thu hồi hoặc hủy lịch đã công bố, nhân viên bị ảnh hưởng nhận thông báo trong app.
- Đổi ca vẫn cần Manager duyệt và kiểm tra lại cả lịch nháp; duyệt nghỉ/đổi ca khóa nhân viên để phối hợp với thao tác phân ca. Staff không có API sửa lịch chính thức.
- Chưa bật đăng ký ca mong muốn; dùng luồng phân ca và yêu cầu hiện có để tránh thêm bước vận hành chưa cần thiết.

API lịch bổ sung:

- `GET/POST /api/admin/shifts`, `PUT /api/admin/shifts/{id}`: quản lý mẫu ca, gồm `breakMinutes` và `active`.
- `GET /api/admin/schedules?from=yyyy-MM-dd&to=yyyy-MM-dd&storeId=...`: xem lịch toàn chuỗi; `storeId` tùy chọn, tối đa 3 tháng.
- `GET /api/manager/shifts`: chỉ trả mẫu đang hoạt động.
- `POST /api/manager/schedules/publish?from=yyyy-MM-dd&to=yyyy-MM-dd`: kiểm tra và công bố tất cả ca nháp trong phạm vi chi nhánh, trong một transaction.
- Cột `shifts.active` mặc định `1`, `shifts.break_minutes` mặc định `0`; script nâng cấp giữ dữ liệu cũ. Số phút nghỉ là thông tin của mẫu ca, chưa thay đổi cách tính giờ chấm công/lương.

- `GET /api/staff/workspace?from=yyyy-MM-dd&to=yyyy-MM-dd`: dữ liệu tổng hợp theo tài khoản đang đăng nhập; khoảng lịch tối đa 63 ngày.
- `GET /api/staff/request-options`: ca của mình gần đây/sắp tới và các ca có thể xin đổi cùng chi nhánh.
- `PUT /api/staff/profile`, `PUT /api/staff/password`.
- `PUT /api/staff/notifications/{id}/read`, `PUT /api/staff/notifications/read-all`.
- `GET /api/requests/mine`, `POST /api/requests`, `PUT /api/requests/{id}/cancel`.
- `PUT /api/manager/requests/{id}`: duyệt/từ chối và áp dụng thay đổi trong transaction.
- `POST /api/manager/announcements`: gửi thông báo cho nhân viên chi nhánh.
- Chấm công tiếp tục dùng `/api/attendance/check-in` và `/api/attendance/check-out/{attendanceId}`; check-out sử dụng ID bản ghi chấm công.

Backend chính: `StaffWorkspaceService`, `StaffRequestService`, `StaffNotificationService`, `StaffViews`, `StaffController`.
Flutter chính: `StaffScreen`, `StaffCubit`, `StaffRepository` và các form/tab trong `lib/presentation/screens/employee/staff_*`.

`db/ensure-unicode.sql` chạy trước JPA để nâng cấp dữ liệu cũ: cột Unicode, kiểu yêu cầu dài 30 ký tự, enum mới và tọa độ nullable cho bản ghi sửa công. Hibernate tiếp tục thêm bảng/cột mới bằng `ddl-auto: update`. Không xóa bảng hoặc dữ liệu cũ. Seeder không đặt lại tên đã được sửa trong hồ sơ.

## Chạy và kiểm thử

Tại thư mục gốc:

```powershell
.\mvnw.cmd spring-boot:run
.\mvnw.cmd test
# Kiểm thử tích hợp tùy chọn, cần SQL Server cấu hình trong application.yml.
# Các fixture kiểm thử nằm trong transaction và tự rollback.
.\mvnw.cmd test '-Dstaff.integration=true'
```

Tại `hrm_app`:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub test/staff_test.dart --dart-define=CAPTURE_UI=true
flutter build apk --debug --no-pub
flutter run -d emulator-5554
```

Ảnh kiểm tra bố cục dùng fixture riêng được xuất tại `hrm_app/build/ui-preview/staff-*.png`.
Các kiểm thử bao gồm quyền vai trò và sở hữu thông báo, duyệt đổi ca/nghỉ/sửa công trên SQL Server, hủy đơn, cập nhật hồ sơ/mật khẩu, tính giờ qua ranh giới tuần, chống gửi lặp, phản hồi lịch đến sai thứ tự, giữ form khi lỗi và sáu mục Staff trên điện thoại.

Cần kiểm tra GPS trên thiết bị thật để xác nhận trải nghiệm quyền vị trí và phạm vi thực tế.
