# Thiết lập đăng nhập Google lần đầu

Mã Flutter và Spring Boot đã có sẵn. Bước còn lại là đăng ký ứng dụng trong Google Cloud bằng tài khoản Google của bạn. OAuth Client ID nhận được là mã nhận diện ứng dụng; luồng này không dùng Client Secret.

**Đăng nhập email và xác minh Google trên điện thoại/máy giả lập chưa thay thế bước đăng ký ứng dụng.** Cần tạo cả Web client và Android client ở bước 3–4. Chuỗi `DAN_WEB_CLIENT_ID_CUA_BAN.apps.googleusercontent.com` trong ví dụ cũ chỉ là chỗ giữ chỗ, không phải Client ID hoạt động.

## 1. Tạo project Google Cloud

1. Mở [Google Cloud Console](https://console.cloud.google.com/).
2. Bấm ô chọn project trên thanh trên cùng → **New project**.
3. Đặt tên **HRM Cafe**, bấm **Create**, rồi chọn project vừa tạo.

## 2. Khai báo ứng dụng đăng nhập

1. Mở [Google Auth Platform → Branding](https://console.cloud.google.com/auth/branding).
2. Nếu có nút **Get started**, bấm để bắt đầu.
3. App name: **HRM Cafe**. User support email và Contact email: chọn/nhập email của bạn.
4. Nếu được hỏi Audience/User type, chọn **External** rồi hoàn tất các bước của biểu mẫu.
5. Trong **Google Auth Platform → Audience**, nếu ứng dụng đang ở chế độ Testing, thêm email Google bạn sẽ dùng thử ở **Test users**.

Đăng nhập chỉ cần thông tin nhận diện cơ bản `openid`, `email`, `profile`. Hướng dẫn gốc: [Google Identity setup](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid).

## 3. Tạo Client ID loại Web application

1. Mở [Google Auth Platform → Clients](https://console.cloud.google.com/auth/clients).
2. Bấm **Create client**.
3. Application type: **Web application**. Name: **HRM Cafe Web**.
4. Ở **Authorized JavaScript origins**, thêm:

   ```text
   http://localhost
   http://localhost:7357
   ```

5. Bấm **Create** và sao chép **Client ID**, dạng `...apps.googleusercontent.com`.

Client ID này được cấu hình cho backend và được app Android dùng làm `serverClientId`. Backend kiểm tra Google ID token theo đúng Client ID này. [Tài liệu Flutter Android](https://pub.dev/packages/google_sign_in_android).

## 4. Tạo Client ID loại Android

Vẫn trong **Clients**, bấm **Create client** một lần nữa:

| Trường | Giá trị điền cho dự án hiện tại |
| --- | --- |
| Application type | Android |
| Name | HRM Cafe Android Debug |
| Package name | `com.example.hrm_app` |
| SHA-1 certificate fingerprint | `69:7A:E0:FF:A9:A2:36:20:8E:17:E6:90:D5:5C:B9:AB:E9:4A:B6:B2` |

Bấm **Create**. Hai client phải thuộc cùng project **HRM Cafe**. Mã SHA-1 trên đã được đọc từ debug keystore của máy đang làm dự án; máy khác hoặc khóa ký khác cần đăng ký SHA-1 tương ứng. [Hướng dẫn Android của Google](https://codelabs.developers.google.com/sign-in-with-google-android).

## 5. Cấu hình và chạy backend

**Dự án này đã được cấu hình Web Client ID:** `793910679996-kbstvnv0cl5db0hni5jk92rgamrmt1rq.apps.googleusercontent.com`. Đây là mã công khai, không phải Client Secret. Khi chạy dự án hiện tại, nếu terminal còn giữ mã mẫu từ lần trước, hãy xóa biến cũ rồi khởi động backend:

```powershell
Remove-Item Env:\GOOGLE_WEB_CLIENT_ID -ErrorAction SilentlyContinue
.\mvnw.cmd spring-boot:run
```

Chỉ chạy một backend trên cổng 8080. Nếu đang có bản chạy, dừng bằng **Ctrl+C** trước khi chạy lệnh trên. Với project Google Cloud khác, dùng cách đặt biến môi trường bên dưới để thay thế cấu hình mặc định.

Dừng backend đang chạy bằng **Ctrl+C** để giải phóng cổng 8080. Mở PowerShell tại thư mục gốc `HRM_manager`, chạy đoạn sau, rồi dán **Web Client ID** đã sao chép từ Google Cloud ở bước 3 khi được hỏi:

```powershell
$taskGoogleClientId = (Read-Host 'Dán Web Client ID từ Google Cloud (bước 3)').Trim()
if ($taskGoogleClientId -notmatch '^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$') {
    throw 'Client ID chưa đúng định dạng. Sao chép Client ID của Web application trong Google Cloud, không dùng chuỗi mẫu.'
}
$env:GOOGLE_WEB_CLIENT_ID = $taskGoogleClientId
.\mvnw.cmd spring-boot:run
```

Biến môi trường trên áp dụng cho terminal hiện tại; đặt lại khi mở terminal mới. Nếu chạy từ nút Run của IDE, thêm `GOOGLE_WEB_CLIENT_ID` vào environment variables của cấu hình Run tương ứng.

Kiểm tra bằng cách mở `http://localhost:8080/api/auth/google/config`: `enabled` phải là `true` và `clientId` phải khớp mã **Web application** vừa tạo. Nếu vẫn thấy chuỗi mẫu, backend cũ chưa được dừng hoặc IDE đang dùng biến môi trường cũ. Sau khi đổi Client ID, dừng rồi chạy lại app Flutter để khởi tạo lại SDK Google.

Backend tự tạo bảng `google_accounts` bằng cơ chế cập nhật schema hiện có. Các tài khoản, mật khẩu và vai trò HRM đang có được giữ nguyên.

## 6. Chạy app và thử đăng nhập

Ở terminal thứ hai:

```powershell
cd hrm_app
flutter pub get
flutter run -d emulator-5554
```

1. Bấm **Đăng nhập bằng Google** và chọn tài khoản Google đã thêm vào Test users.
2. Lần đầu, app mở **Liên kết tài khoản Google**. Nhập số điện thoại và mật khẩu HRM đã được cấp, ví dụ tài khoản Staff mẫu `0901000003 / 123456` nếu chưa đổi mật khẩu.
3. Bấm **Liên kết và đăng nhập**. App mở màn hình theo vai trò hiện có.
4. Đăng xuất và thử lại bằng Google: không cần nhập mật khẩu HRM nữa.

Ứng dụng lấy Client ID công khai từ backend khi cần đăng nhập; chỉ cần cấu hình ở bước 5. Nếu bạn dùng tùy chọn `--dart-define=GOOGLE_WEB_CLIENT_ID=...`, giá trị đó phải trùng với backend.

### Chạy bản Web

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=API_BASE_URL=http://localhost:8080/api
```

Bản Web dùng nút do Google Identity Services tạo và nhận kết quả qua authentication events. Backend cho phép CORS từ `http://localhost:7357` và `http://127.0.0.1:7357`. [Tài liệu Flutter Web](https://pub.dev/packages/google_sign_in_web).

### iOS/macOS

Cần tạo thêm OAuth client tương ứng, cấu hình URL scheme theo [google_sign_in_ios](https://pub.dev/packages/google_sign_in_ios), và có thể truyền `GOOGLE_IOS_CLIENT_ID` bằng dart-define. Chưa kiểm thử iOS/macOS trong môi trường Windows này.

## Khi gặp lỗi

- **`Clear Failed` / `no provider dependencies found`**: dependency Credential Manager đã có sẵn trong `google_sign_in_android`; lỗi cũng xảy ra khi Google Play services quá cũ, nên không cần thêm trùng dependency. App hiện bỏ qua lỗi xóa phiên cũ và vẫn thử xác thực; nếu nhà cung cấp Google không hoạt động thì cần sửa môi trường Android.
  - Máy giả lập `Pixel_4a` hiện dùng Android 12 (API 31), image **Google APIs**, Google Play services **22.50.14**. Credential Manager yêu cầu Play services tối thiểu version code `230815045`, cao hơn bản `225014047` đang cài.
  - Trong Android Studio → **Device Manager** → **Create Virtual Device**, chọn thiết bị có biểu tượng **Google Play**, tải system image **Google Play** mới (ví dụ API 35/36) rồi tạo máy giả lập. Image **Google APIs** hiện tại không bật Play Store để tự cập nhật dễ dàng.
  - Mở **Play Store** trong máy giả lập mới, đăng nhập Google và cập nhật Google Play services nếu được yêu cầu; sau đó chạy `flutter devices` và `flutter run -d <ID-máy-mới>` tại `hrm_app`.
  - Nếu dùng điện thoại thật: cập nhật Google Play services, kiểm tra đã thêm tài khoản Google trong Cài đặt, rồi thử lại. [Hướng dẫn quản lý AVD của Android](https://developer.android.com/studio/run/managing-avds).
- **Google chưa được cấu hình**: kiểm tra biến `GOOGLE_WEB_CLIENT_ID` của tiến trình backend và khởi động lại backend.
- **Sai cấu hình / đóng màn chọn Google mà chưa vào được**: đối chiếu package, SHA-1 và Web Client ID; bảo đảm hai OAuth client cùng project.
- **Tài khoản HRM đã liên kết Google khác**: sử dụng Google đã liên kết. Hệ thống không tự thay liên kết bằng email hồ sơ.
- **Sai số điện thoại/mật khẩu khi liên kết**: dùng thông tin đăng nhập HRM, không nhập mật khẩu Google.
- **Google token hết hạn**: đóng form liên kết và chọn lại tài khoản Google.
- **Port 8080 already in use**: dừng bản backend cũ rồi chạy lại một bản duy nhất.

## Ghi chú triển khai và kiểm thử

- `GET /api/auth/google/config` trả trạng thái và Web Client ID công khai; không trả Client Secret.
- `POST /api/auth/google` xác minh chữ ký Google, issuer, audience, thời hạn và email đã xác minh. Nhận diện tài khoản bằng `sub`, không tự ghép theo email hồ sơ có thể chỉnh sửa. [Google backend authentication](https://developers.google.com/identity/sign-in/android/backend-auth).
- `POST /api/auth/google/link` kiểm tra lại Google token và số điện thoại/mật khẩu HRM trước khi lưu liên kết một-một. Không tạo tài khoản hay tự cấp quyền Admin/Manager.
- App lưu JWT do backend cấp, không dùng Google ID token làm JWT của HRM. Token và mật khẩu được loại khỏi chuỗi log DTO.
- Biểu tượng nút native lấy từ [Google branding assets](https://developers.google.com/identity/branding-guidelines). Bản Web dùng nút SDK Google.

```powershell
# Tại thư mục gốc; integration cần SQL Server, fixture tự rollback.
.\mvnw.cmd test
.\mvnw.cmd test '-Dgoogle.integration=true'

# Tại hrm_app
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Các kiểm thử kiểm tra chữ ký giả/audience sai/issuer sai/token hết hạn, liên kết bằng mật khẩu, giữ nguyên ba vai trò, chống gán Google cho tài khoản khác, hủy thao tác, gửi lặp, lưu JWT và điều hướng. Cần Web Client ID thật để kiểm thử chọn tài khoản Google trực tiếp.
