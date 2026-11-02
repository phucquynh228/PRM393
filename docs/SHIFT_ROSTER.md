# Phân ca theo buổi, lịch mặc định và định mức

## Cách dùng

1. **Quản lý → Phân ca → Định mức ca**: chọn mẫu giờ cho **Ca Sáng, Ca Chiều, Ca Tối** và số người cần trong từng ca của chi nhánh. Ví dụ sáng 2, chiều 2, tối 4. Giá trị 0 tắt cảnh báo định mức của ca đó; hệ thống không tự áp đặt số nhân viên yêu cầu. Mẫu giờ do Admin quản lý tại **Lịch làm → Mẫu ca**.
2. **Đội ngũ → Thêm/Chỉnh sửa nhân viên → Ca làm việc mặc định**: đánh dấu ca theo từng thứ từ thứ Hai đến Chủ nhật. Có thể đặt ca tối cho các ngày nhân viên đăng ký cố định. Hồ sơ chi tiết của quản lý và hồ sơ cá nhân của nhân viên đều hiển thị ca mặc định; nhân viên không tự sửa phần này.
3. **Phân ca → Tuần**: chuyển đến tuần cần tạo, bấm **Tạo nháp tuần mới**. Hệ thống tự điền ca mặc định trong tuần đang xem, trả số ca đã tạo, ca đã có và từng ca bỏ qua cùng lý do. Không tạo/công bố lịch khi chỉ mở hoặc chuyển tuần.
4. Mỗi ngày luôn có ba khối ca, kể cả chưa có người. Bấm **Thêm nhân sự** để tìm và đánh dấu nhiều nhân viên trong chi nhánh rồi lưu một lần thành nháp. Người đã có trong ca được đánh dấu sẵn và không thêm trùng. Lựa chọn được giữ khi máy chủ từ chối một nhân viên.
5. Kiểm tra các khối màu đỏ và dòng **Thiếu N người · X/Y nhân viên**, điều chỉnh qua menu của từng người rồi **Công bố**. Bộ lọc nháp/đã công bố chỉ thay đổi danh sách hiển thị, không làm sai số người dùng so sánh định mức.

Điện thoại xếp ba khối theo chiều dọc; màn hình rộng xếp theo ba cột. Thanh tuần cho chọn từng ngày và **Xem cả tuần**. Vẫn có chế độ ngày/tháng.

## Quy tắc

- Chỉ quản lý đang hoạt động trong chi nhánh được cấu hình và phân ca cho nhân viên STAFF đang hoạt động tại chi nhánh đó. Cùng một mẫu giờ không thể gán cho hai buổi trong cấu hình.
- Ca mặc định lưu theo thứ và buổi, không phụ thuộc mã mẫu giờ. Khi nhân viên chuyển chi nhánh, sở thích này được giữ; tuần mới sử dụng mẫu giờ của chi nhánh mới. Ca đã tạo giữ nguyên giờ và chi nhánh lịch sử.
- Tạo tuần hỗ trợ thứ Hai của tuần hiện tại/tương lai trong một năm. Ca đã bắt đầu, mẫu chưa chọn/ngừng dùng, ngày nghỉ đã duyệt và lịch chồng giờ (gồm nháp/qua đêm) được bỏ qua có lý do. Các ca hợp lệ vẫn được tạo nháp.
- Tạo lại tuần không ghi đè phân công hiện có. Xóa nháp tạo từ giao diện theo ca lưu dấu `CANCELLED` để lần tạo lại không tự khôi phục ca quản lý đã bỏ. Có thể chủ động dùng **Thêm nhân sự** để phân công lại. Đổi ca mặc định không sửa các lịch đã tạo.
- Thêm nhiều người kiểm tra toàn bộ lựa chọn trước khi lưu: nếu một người không hợp lệ, không thêm một phần danh sách. Khóa chi nhánh/nhân viên phối hợp với điều chuyển, duyệt nghỉ và thao tác tạo lịch đồng thời.
- Định mức đếm số nhân viên khác nhau trong cả lịch nháp và đã công bố, không tính `ON_LEAVE`, `ABSENT`, `CANCELLED`. Thiếu nhân sự là cảnh báo, không cấm công bố; quản lý tự quyết định công bố sau khi xem xét.
- Nháp không gửi thông báo và không hiển thị cho nhân viên. Công bố vẫn kiểm tra lại thời gian, trùng lịch, ngày nghỉ và gửi thông báo theo luồng hiện có.
- Cấu hình buổi cho lịch mới được lưu vào `user_schedules.shift_slot`. Lịch cũ chưa có trường này được phân nhóm theo giờ bắt đầu: trước 12h là Sáng, từ 12h đến trước 17h là Chiều, từ 17h là Tối. Cấu hình mặc định chọn mẫu đang hoạt động đầu tiên theo các khoảng này; quản lý có thể chọn lại mẫu phù hợp.
- Nếu Admin tạo phiên bản mới/ngừng dùng mẫu ca, quản lý cần chọn lại mẫu đang hoạt động trong **Định mức ca**. Lịch nháp dùng mẫu cũ vẫn phải được điều chỉnh trước khi công bố theo quy tắc hiện có.

## API và lưu trữ

- `GET /api/manager/roster/settings`: ba cấu hình buổi, giờ ca, trạng thái mẫu và `requiredStaff`.
- `PUT /api/manager/roster/settings`: `{ "slots": [{ "slot": "MORNING", "shiftId": 1, "requiredStaff": 2 }, ...] }`, đúng ba buổi, định mức 0–200.
- `POST /api/manager/schedules/batch`: `{ "date": "2026-11-02", "slot": "EVENING", "userIds": [3, 4] }`.
- `POST /api/manager/schedules/generate-week`: `{ "weekStart": "2026-11-02" }`; trả `created`, `existing`, `skipped`.
- API `POST /api/manager/staff`, `PUT /api/manager/staff/{id}` nhận thêm `fixedRoster: [{ "dayOfWeek": 1, "slot": "EVENING" }]`. Thứ 1–7 tương ứng Hai–Chủ nhật; tối đa 21 cặp, không trùng. Bỏ trường này giữ cấu hình cũ, gửi `[]` xóa ca mặc định.

Hibernate `ddl-auto: update` thêm bảng `user_fixed_roster`, `branch_shift_plans` và cột `user_schedules.shift_slot`, không xóa dữ liệu hiện tại. Khởi động lại backend để cập nhật schema, sau đó chạy lại ứng dụng Flutter.

## Kiểm tra

```powershell
.\mvnw.cmd test
# SQL Server, fixture tự rollback:
.\mvnw.cmd test '-Droster.integration=true' '-Dstaff.integration=true'
cd hrm_app
flutter analyze
flutter test --concurrency=1
flutter test test/features/schedule/shift_roster_test.dart --dart-define=CAPTURE_UI=true
```

Kiểm thử bao gồm lưu hồ sơ, phân quyền, chống thêm một phần danh sách, tạo lặp không trùng, nghỉ đã duyệt, lịch chồng giờ, bỏ ca nháp, công bố/thông báo và bố cục điện thoại nhỏ/màn hình rộng.
