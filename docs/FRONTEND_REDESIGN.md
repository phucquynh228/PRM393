# Cập nhật frontend HRM Cafe

Giao diện Flutter ưu tiên điện thoại, nền sáng và màu nâu cà phê. Nội dung hiện dùng tiếng Việt và locale Material `vi_VN`.

## Chức năng đã cập nhật

- Đăng nhập: lỗi tại trường, lỗi máy chủ trong form, tự điền tài khoản mẫu chỉ ở debug, bố cục hai cột trên màn hình rộng.
- Nhân viên: Hôm nay / Chấm công / Yêu cầu; lịch sử chấm công độc lập; check-in/check-out theo trạng thái ca; khóa thao tác khi đang gửi.
- Check-out gọi API với ID lấy từ lịch sử, đối chiếu theo scheduleId; không gửi ID 0.
- Trạng thái nhân viên được tạo theo route và hủy khi rời màn hình, tránh giữ dữ liệu của tài khoản cũ.
- Manager: danh sách nhân viên lấy từ trường staff của GET /manager/branch; mặc định mở Tổng quan; lưới tuần trên màn hình rộng, danh sách theo ngày trên điện thoại.
- Manager: tìm kiếm đội ngũ, lọc chấm công, badge đơn chờ duyệt, giữ form khi lỗi duyệt đơn, biểu đồ so sánh ca lên lịch và lượt chấm công.
- Bộ lọc ngày của lịch và chấm công độc lập. Phản hồi cũ từ lần lọc trước không ghi đè kết quả mới.
- Admin: tìm kiếm/lọc chi nhánh, tài khoản, chấm công; bảng phân trang trên màn hình rộng.
- Form dài mở toàn màn hình trên điện thoại; kiểm tra số điện thoại, mật khẩu, tọa độ và bán kính; chờ API xác nhận trước khi đóng.
- Font Plus Jakarta Sans được đóng gói trong assets/fonts kèm giấy phép OFL; không tải font khi chạy app.
- GPS lấy vị trí hiện tại và báo lỗi rõ khi không lấy được; đã bỏ tọa độ giả mặc định và không gắn nhãn phạm vi hợp lệ trước khi kiểm tra.

## Cấu trúc chính

- lib/core/theme/app_theme.dart: màu, typography và theme thành phần.
- lib/core/network/api_error.dart: thông báo lỗi API phù hợp người dùng.
- lib/presentation/widgets/app_shell.dart: navigation dưới 760 logical pixels; navigation rail từ 760; sidebar mở rộng từ 1150.
- lib/presentation/widgets/content_widgets.dart: card, heading, metric grid co giãn với nội dung.
- lib/presentation/widgets/directory_list.dart: tìm kiếm, lọc và bảng phân trang từ 900 logical pixels.
- lib/presentation/widgets/adaptive_form.dart: form thích ứng theo kích thước màn hình.
- lib/presentation/blocs/admin và branch: Cubit quản lý tải dữ liệu và lỗi.
- lib/presentation/screens/employee: danh sách yêu cầu và form gửi đơn.
- lib/data/models/attendance_record.dart: model bản ghi chấm công.

## Chạy ứng dụng

Tại thư mục hrm_app:

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

Android emulator dùng http://10.0.2.2:8080/api. Với điện thoại thật, truyền địa chỉ LAN của máy chạy Spring Boot:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8080/api
flutter build apk --debug --dart-define=API_BASE_URL=http://YOUR_PC_IP:8080/api
```

API_BASE_URL nhận qua dart-define. Cấu hình dự phòng địa chỉ thiết bị thật của dự án được giữ trong main.dart. APK mặc định dùng cấu hình này.

## Kiểm tra

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --dart-define=CAPTURE_UI=true
flutter build web --no-pub
flutter build apk --debug --no-pub
```

Ảnh QA được xuất vào build/ui-preview. Dữ liệu trong ảnh là fixture kiểm thử, không phải dữ liệu vận hành.

Các kiểm thử bao gồm: API lịch sử/check-out, không báo thành công khi check-out lỗi, chống gửi lặp, giữ dữ liệu khi refresh lỗi, tải nhân viên đúng endpoint, phản hồi bộ lọc sai thứ tự, validation đăng nhập, giữ form khi lưu lỗi, độ tương phản chữ và bố cục ở nhiều kích thước/chữ phóng to/bàn phím.

## Kiểm tra thủ công cần backend và thiết bị

1. Đăng nhập từng vai trò với backend và cơ sở dữ liệu đang chạy.
2. Manager tạo và công bố ca; xác nhận ca xuất hiện ở tài khoản nhân viên.
3. Trên thiết bị Android thật: cấp/từ chối quyền GPS, tắt GPS, vào/ngoài vùng cho phép; thực hiện check-in/check-out và đối chiếu bản ghi.
4. Nhân viên gửi đơn; Manager duyệt/từ chối; xem lại ghi chú phản hồi.
5. Thử lưu form khi backend ngừng hoạt động, bảo đảm nội dung nhập vẫn còn.

Chưa có thiết bị Android kết nối trong phiên thực hiện. Kiểm thử tự động sử dụng repository/API giả lập; chưa xác nhận quy trình chấm công với GPS thật và cơ sở dữ liệu thật.

## Phạm vi mở rộng cần API

- Lịch tuần cho nhân viên: backend hiện chỉ cung cấp lịch hôm nay cho vai trò này.
- Khoảng cách và trạng thái trong/ngoài vùng trước check-in: cần dữ liệu vị trí chi nhánh cho nhân viên.
- Chọn nhiều ngôn ngữ: hiện giao diện tiếng Việt; chưa có màn chọn ngôn ngữ hay bộ bản dịch tiếng Anh.

Nguồn tham khảo: [Frappe HR](https://github.com/frappe/hrms), [OrangeHRM](https://github.com/orangehrm/orangehrm), [Flutter Material 3 Demo](https://github.com/flutter/samples/tree/main/material_3_demo).

## Dashboard quản trị và chi nhánh (cập nhật bổ sung)

- Manager mở Tổng quan mặc định, gồm chấm công hôm nay, ca hôm nay, đơn chờ duyệt, ca nháp tuần hiện tại và hoạt động mới nhất.
- Admin có tổng quan chấm công hôm nay, chi nhánh/nhân sự, chi nhánh chưa có quản lý và các lối tắt thêm chi nhánh/tạo tài khoản.
- Cả hai dashboard có Chấm công của tôi để check-in/check-out ngay trên trang; dữ liệu lấy từ lịch cá nhân và lịch sử của tài khoản đăng nhập. Cần có ca được công bố mới có nút chấm công.
- Mobile ưu tiên khối chấm công cá nhân ngay sau banner; desktop đặt cạnh phần tổng quan. Sáu chức năng Manager được bố trí thành bốn mục chính và menu Thêm trên mobile.
- Dashboard dùng nâu espresso và trắng làm chủ đạo; điểm nhấn mocha/caramel, icon ly cà phê ở banner và nhận diện ứng dụng. Màu xanh/đỏ chỉ dùng để phân biệt trạng thái nghiệp vụ.
- Manager đọc đúng trường records từ API chấm công, đồng thời hỗ trợ items. Trạng thái NOT_CHECKED_IN được hiển thị là Chờ vào ca.
- Dữ liệu hôm nay của dashboard độc lập với bộ lọc ngày trên các màn khác. Admin mặc định mở danh sách chấm công theo ngày hiện tại.
- Thêm sửa trực tiếp ở danh sách chi nhánh và nhân viên; phân ca, thêm người, công bố ca nháp và duyệt đơn có thể mở/thực hiện từ tổng quan.
- Ảnh mới: build/ui-preview/admin-dashboard-desktop.png, manager-dashboard-desktop.png và các bản phone.

Cập nhật nhận diện: banner nâu espresso, khối chấm công nâu kem, thẻ thống kê các sắc nâu và icon ly cà phê ở thanh tiêu đề/sidebar.
