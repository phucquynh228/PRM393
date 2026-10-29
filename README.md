# HRM Manager

Ứng dụng quản lý nhân sự chuỗi cafe: backend Spring Boot/SQL Server và app Flutter dành cho Admin, Manager, Staff.

## Cấu trúc

```text
HRM_manager/
├── src/                  # Backend Maven: package theo chức năng
├── hrm_app/              # Flutter: app, core, features, shared
├── database/backups/     # Bản xuất SQL để tham khảo/khôi phục
├── scripts/database/     # Script dữ liệu chạy chủ động
├── tools/password/       # Công cụ Java độc lập tạo BCrypt cho dữ liệu mẫu
├── docs/                 # Kiến trúc, nghiệp vụ và hướng dẫn
├── pom.xml               # Cấu hình backend
└── target/               # Kết quả Maven tự sinh, không đặt mã nguồn ở đây
```

Xem [sơ đồ package và quy tắc đặt file](docs/PROJECT_STRUCTURE.md).

## Chạy backend

Cần JDK 17 và SQL Server. Cấu hình kết nối trong `src/main/resources/application.yml`.

```powershell
.\mvnw.cmd spring-boot:run
```

API chạy tại `http://localhost:8080/api`.

## Chạy Flutter

Chạy cả Android emulator và điện thoại USB từ thư mục gốc:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/android/run.ps1 -Target all
```

Script tự mở emulator, khởi động backend nếu cần, cấu hình kết nối USB và cài app lên các thiết bị Android đã kết nối.
Trong VS Code, chọn **HRM: Emulator + Samsung USB** rồi F5 để debug và hot reload cả hai.
Xem [hướng dẫn Android emulator và USB](docs/ANDROID_DEV_SETUP.md) để chạy riêng từng máy hoặc đổi điện thoại.

```powershell
cd hrm_app
flutter pub get
flutter run -d emulator-5554
```

Điểm vào: `hrm_app/lib/main.dart`. Khởi tạo dependency: `hrm_app/lib/app/bootstrap.dart`.
Địa chỉ API và nhận diện thiết bị: `hrm_app/lib/core/config/api_config.dart`. Emulator mặc định dùng `10.0.2.2`; điện thoại USB dùng `127.0.0.1` sau khi chạy script chuẩn bị kết nối.
Có thể cấu hình địa chỉ khi chạy bằng `--dart-define=API_BASE_URL=http://<host>:8080/api`.

## Kiểm thử

```powershell
# Tại thư mục gốc. Dùng clean sau khi chuyển package để bỏ class cũ.
.\mvnw.cmd clean test
# Kiểm thử tích hợp SQL Server, fixture tự rollback.
.\mvnw.cmd test '-Dstaff.integration=true' '-Dgoogle.integration=true'

# Tại hrm_app
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

## Tài liệu

- [Cấu trúc project](docs/PROJECT_STRUCTURE.md)
- [Ngừng hoạt động chi nhánh và điều chuyển nhân sự](docs/BRANCH_LIFECYCLE.md)
- [Chức năng Staff và quản lý lịch](docs/STAFF_FEATURES.md)
- [Phân ca theo buổi, ca mặc định và định mức](docs/SHIFT_ROSTER.md)
- [Xuất báo cáo chấm công dành cho admin](docs/ADMIN_ATTENDANCE_REPORT.md)
- [Giao diện và điều hướng](docs/FRONTEND_REDESIGN.md)
- [Đăng nhập Google](docs/GOOGLE_LOGIN_SETUP.md)
- [Chọn vị trí chi nhánh](docs/BRANCH_MAP_PICKER.md)
- [Dữ liệu và script SQL](database/README.md)
