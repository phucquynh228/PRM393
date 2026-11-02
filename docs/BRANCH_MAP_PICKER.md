# Chọn vị trí chi nhánh trên bản đồ

Vào **Admin → Chi nhánh → Thêm chi nhánh / Chỉnh sửa → Vị trí chấm công**.

- Chạm lên bản đồ để đặt ghim, hoặc kéo trực tiếp ghim đến địa điểm của quán.
- Dùng hai ngón tay hoặc nút **+ / −** để phóng to, thu nhỏ. Nút **Về ghim đã chọn** đưa bản đồ về điểm đang chọn.
- Bấm **Lấy vị trí hiện tại** khi đang ở quán, cho phép quyền vị trí, rồi căn lại ghim nếu cần. Chỉ yêu cầu GPS sau khi bấm nút.
- Vòng tròn quanh ghim thể hiện **Bán kính cho phép (m)**. Thay đổi bán kính sẽ cập nhật vòng tròn ngay.
- Mục **Nhập tọa độ thủ công** cho phép nhập vĩ độ/kinh độ; bấm **Áp dụng tọa độ** để cập nhật ghim trước khi lưu.
- Bấm **Lưu chi nhánh** để lưu tọa độ cùng thông tin quán. Đóng/hủy form không lưu thay đổi.

Khi sửa chi nhánh, bản đồ mở ở tọa độ đã lưu. Với chi nhánh chưa có vị trí, bản đồ ban đầu xem khu vực TP.HCM nhưng vẫn yêu cầu chọn một điểm hoặc lấy GPS trước khi lưu. Kéo bản đồ để xem khu vực khác không tự thay đổi tọa độ quán.

## Khi không lấy được vị trí hoặc bản đồ

- Bật GPS và cấp quyền vị trí khi ứng dụng hỏi. Nếu đã chặn quyền, mở **Cài đặt → Ứng dụng → HRM → Quyền → Vị trí**.
- Bản đồ cần Internet. Nếu tải lỗi, có thể bấm **Tải lại bản đồ**, dùng GPS hoặc nhập tọa độ thủ công. Lỗi GPS không xóa vị trí đang chọn.
- Máy giả lập trả vị trí mô phỏng của thiết bị, có thể khác địa điểm thật; vẫn có thể kéo ghim để đặt vị trí quán. Luồng chấm công tiếp tục từ chối vị trí giả lập như trước.

## Cấu hình kỹ thuật

Sử dụng [`flutter_map`](https://pub.dev/packages/flutter_map) và tile OpenStreetMap qua HTTPS, không cần Maps API key. Android khai báo quyền vị trí coarse/fine; iOS khai báo lý do sử dụng vị trí khi mở app.

Attribution OpenStreetMap luôn hiển thị trên bản đồ; tile provider giữ ổn định khi kéo ghim, dùng bộ nhớ đệm mặc định của thư viện. Không tải bản đồ hàng loạt hay tải trước để dùng offline. Xem [chính sách tile OpenStreetMap](https://operations.osmfoundation.org/policies/tiles/).

Có thể đổi endpoint tile bằng `--dart-define=MAP_TILE_URL=https://.../{z}/{x}/{y}.png` cho dịch vụ tương thích; khi đổi nguồn cần cập nhật attribution theo nhà cung cấp. API backend vẫn nhận `latitude`, `longitude`, `allowedRadius` như trước.

```powershell
cd hrm_app
flutter pub get
flutter run -d emulator-5554
```

Khi thêm dependency native hoặc quyền vị trí, cần chạy lại app đầy đủ; hot reload không cập nhật cấu hình Android/iOS. iOS chưa được chạy thử trong môi trường Windows.
