# Chạy Android emulator và điện thoại USB

Mở thư mục gốc `HRM_manager` trong VS Code. Cần Flutter, JDK 17, Android SDK, một AVD và SQL Server của project đang chạy.
Trên điện thoại, bật Developer options → USB debugging, cắm cáp dữ liệu, mở khóa màn hình và chấp nhận thông báo cho phép máy tính debug.

## Chạy cả hai ngay

Tại thư mục gốc:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/android/run.ps1 -Target all
```

Script chọn AVD đầu tiên nếu chưa có `emulator-5554`, khởi động backend nếu API chưa chạy, tạo `adb reverse tcp:8080 tcp:8080` riêng cho từng thiết bị, build một APK rồi cài và mở app trên tất cả thiết bị Android đã được ADB cấp quyền. Lệnh này kết thúc sau khi mở app và không giữ phiên hot reload.

Có thể chỉ định AVD:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/android/run.ps1 -Target all -AvdName Pixel_4a
```

Backend do script mở chạy nền, log ở `target/android-dev/backend.out.log` và `backend.err.log`. Backend vẫn chạy sau khi dừng app; chỉ mở thêm backend khi API chưa sẵn sàng.

## Debug trong VS Code

Trong Run and Debug, chọn cấu hình rồi F5:

- **HRM: Emulator + Samsung USB**: hai phiên debug, có hot reload cho từng phiên.
- **HRM: Emulator**: emulator tại `emulator-5554`.
- **HRM: Samsung USB**: Samsung đang cắm cáp, serial `RFCX40BJXGX`.
- **HRM: Android selected device**: thiết bị chọn ở thanh trạng thái Flutter.

Mỗi cấu hình chạy tác vụ chuẩn bị kết nối trước khi mở app. Khi đổi điện thoại, đổi `deviceId` trong `.vscode/launch.json`, hoặc dùng cấu hình thiết bị đang chọn. `run.ps1 -Target usb` tự nhận thiết bị nên không cần đổi serial trong script.

## Chạy riêng với hot reload trong terminal

```powershell
# Điện thoại USB: tự chọn thiết bị đã cấp quyền.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/android/run.ps1 -Target usb

# Emulator: có thể chạy trong terminal thứ hai để dùng cùng lúc.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/android/run.ps1 -Target emulator
```

Nhấn `r` để hot reload, `R` để hot restart và `q` để kết thúc phiên Flutter.

## Android Studio hoặc chạy Flutter thủ công

Chuẩn bị backend và đường truyền trước:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/android/prepare.ps1 -StartEmulator -StartBackend
```

Sau đó chọn thiết bị trong Android Studio và chạy `hrm_app/lib/main.dart`. App tự chọn `10.0.2.2` trên emulator và `127.0.0.1` trên điện thoại thật. Các cấu hình VS Code/script dùng cùng `API_BASE_URL=http://127.0.0.1:8080/api` cho cả hai qua ADB reverse.

Sau khi rút/cắm lại cáp hoặc khởi động lại thiết bị, chạy lại tác vụ chuẩn bị để thiết lập reverse mới. Không cần cùng mạng Wi-Fi hay mở cổng Windows Firewall cho cách kết nối này. [Cách Android hướng dẫn truy cập server phát triển qua ADB reverse](https://developer.android.com/develop/ui/views/layout/webapps/access-local-server).

Nếu dùng Wi-Fi thay vì USB, đặt địa chỉ LAN thực tế của máy chạy backend:

```powershell
cd hrm_app
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<IP-may-tinh>:8080/api
```

## Kiểm tra khi không kết nối được

- Backend: mở `http://127.0.0.1:8080/api/auth/google/config` trên máy tính. Script kiểm tra endpoint này trước khi chạy app.
- Không thấy điện thoại: kiểm tra cáp dữ liệu, USB debugging và thông báo cấp quyền; dùng `flutter devices` để xem danh sách.
- Không có AVD: tạo thiết bị trong Android Studio Device Manager rồi chạy lại.
- Log backend báo kết nối SQL Server thất bại: khởi động SQL Server và kiểm tra cấu hình trong `src/main/resources/application.yml`.
- Tài khoản bị báo liên kết với thiết bị khác: dùng tài khoản riêng trên mỗi thiết bị, hoặc đặt lại liên kết thiết bị từ tài khoản Admin. Script giữ nguyên dữ liệu và liên kết tài khoản hiện có.
