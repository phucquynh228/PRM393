# Xuất báo cáo chấm công dành cho admin

Vào **Admin → Chấm công → Xuất báo cáo**:

1. Màn hình **Báo cáo chấm công** mặc định theo tháng hiện tại. Bấm khoảng thời gian để chọn **Theo ngày**, **Theo tháng** hoặc **Theo năm** (2000–2100).
2. Mở **Lọc nhân viên và chi nhánh**, hoặc để **Tất cả**. Bộ lọc báo cáo độc lập với bộ lọc tra cứu danh sách.
3. Xem các chỉ số và bảng tổng hợp theo từng nhân viên từ dữ liệu thực tế.
4. Nhấn **Xuất Excel** hoặc **Xuất PDF**. Android/iOS cho chọn nơi lưu; trình duyệt tải file xuống, desktop lưu trong Downloads. Xuất file giữ nguyên kỳ và bộ lọc đang xem.

Chỉ số **Nhân viên** đếm số nhân viên có ca đã công bố trong kỳ và phạm vi chọn. **Ca đã hoàn thành** đếm ca có đủ giờ vào và ra. **Đi muộn** đếm lượt vào ca trễ từ một phút so với giờ bắt đầu theo ngày phân ca. **Vắng không phép** đếm ca có trạng thái `ABSENT`, không gồm `ON_LEAVE` và không tự suy đoán từ ca chưa chấm công. Cột **Ca làm** trong bảng là số ca đã hoàn thành.

Excel là file `.xlsx` thực sự với hai sheet: **Tong hop** có chỉ số và bảng nhân viên; **Chi tiet** có từng ca, giờ vào/ra, số phút làm thực tế, số phút muộn, trạng thái và dấu hiệu điều chỉnh. Cột số dùng kiểu số; tên nhân viên luôn là văn bản để tránh bị hiểu thành công thức.

PDF A4 gồm tiêu đề Coffee HRM, kỳ báo cáo, chỉ số và bảng nhân viên. Font tiếng Việt nhúng từ Plus Jakarta Sans (giấy phép OFL trong `src/main/resources/fonts`). Báo cáo tự chia trang, lặp tiêu đề bảng và có số trang.

- Kỳ báo cáo tính theo **ngày phân ca**, gồm cả hai đầu kỳ. Ca qua đêm thuộc ngày phân ca dù giờ vào/ra nằm ở ngày hôm sau.
- Chỉ lấy ca đã công bố; loại ca nháp và ca đã hủy. Ca chưa có chấm công vẫn có trong file, giữ trạng thái đã lưu (chưa chấm công, vắng mặt, nghỉ phép...). Không tự suy đoán vắng mặt.
- Chi nhánh lấy từ lịch phân công và tên/mã đã lưu cùng lịch, giữ lịch sử khi điều chuyển nhân viên. Lịch cũ chưa lưu chi nhánh dùng chi nhánh hiện tại theo quy ước hiện có của hệ thống.
- Số phút thực tế là thời gian từ vào đến ra, chưa trừ giờ nghỉ; để trống khi chưa đủ giờ vào/ra. Đây không phải số công hoặc thời gian dùng tính lương.
- Nếu kỳ/phạm vi chọn không có dữ liệu, hiển thị thông báo và không lưu file.

API tổng hợp: `GET /api/admin/attendance/report?period=month&date=2026-10-01&userId=2&storeId=3`, trả về JSON `ApiResponse` với chỉ số và `employees`. Khi không có dữ liệu, trả về chỉ số 0 và danh sách rỗng; màn hình vô hiệu hóa xuất file.

API file: `GET /api/admin/attendance/export?format=xlsx&period=month&date=2026-10-01&userId=2&storeId=3`

- Chỉ tài khoản `ADMIN` được gọi, dùng JWT như các API admin khác.
- `period`: `day`, `month`, `year`; mặc định `day`. `date` bắt buộc theo `yyyy-MM-dd`; với kỳ tháng/năm, ngày được quy về toàn tháng/năm chứa ngày đó.
- `userId`, `storeId` tùy chọn; áp dụng đồng thời khi có cả hai.
- `format`: `xlsx`, `pdf`, hoặc `csv` để tương thích API cũ (mặc định `csv`). Giao diện chỉ có Excel và PDF.
- Thành công: MIME Excel/PDF/CSV tương ứng, attachment có tên chứa kỳ và bộ lọc, `Cache-Control: no-store`.
- Ngày/kỳ không hợp lệ hoặc không có dữ liệu: HTTP 400 với JSON `message`.

Kiểm tra:

```powershell
.\mvnw.cmd -q '-Dtest=AttendanceReportServiceTest,AttendanceReportDocumentServiceTest,AdminAttendanceReportControllerTest' test
# SQL Server theo application.yml, dữ liệu kiểm thử tự rollback:
.\mvnw.cmd -q '-Dtest=AttendanceReportIntegrationTest' '-Dattendance.report.integration=true' test
cd hrm_app
flutter analyze
flutter test test/features/admin/attendance_report_test.dart
```

Thư viện lưu file dùng [file_saver 0.2.13](https://pub.dev/packages/file_saver/versions/0.2.13), tương thích với nhóm Firebase và `web 0.5.1` hiện tại của dự án.
