# Cấu trúc package và thư mục

Project nhóm mã theo chức năng. Khi sửa lịch làm, bắt đầu ở `schedule`; khi sửa đăng nhập, bắt đầu ở `auth`. Trong mỗi chức năng, lớp HTTP, nghiệp vụ và dữ liệu có thư mục riêng.

## Backend

Giữ cấu trúc Maven chuẩn: `src/main/java`, `src/main/resources`, `src/test/java`.
`com.cafehr.HrmManagerApplication` vẫn ở package gốc để Spring tự quét các package con.

```text
src/main/java/com/cafehr/
├── HrmManagerApplication.java
├── admin/           # Quản trị toàn chuỗi, dashboard
├── attendance/      # Check-in/out, lịch sử chấm công
├── auth/            # Đăng nhập, Google, liên kết tài khoản
├── bootstrap/       # DataSeeder cho database mới
├── branch/          # Chi nhánh và các thao tác của Manager
├── common/          # ApiResponse, lỗi dùng chung, GlobalExceptionHandler
├── config/          # Cấu hình Spring/Security
├── notification/    # Thông báo và nhắc ca
├── schedule/        # Mẫu ca, lịch phân công, kiểm tra trùng giờ
├── security/        # JWT và UserDetails dùng chung
├── staff/           # Workspace, yêu cầu đổi ca/nghỉ/sửa công, hồ sơ cá nhân
├── system/          # Cấu hình lưu trong database
└── user/            # Tài khoản, vai trò và chi nhánh của người dùng
```

Ví dụ một chức năng:

```text
schedule/
├── controller/      # ScheduleController, AdminScheduleController
├── dto/             # Dữ liệu request/response
├── entity/          # Shift, UserSchedule, ScheduleStatus
├── repository/      # Truy vấn JPA
└── service/         # ScheduleRules
```

- `controller`: nhận request, xác thực dữ liệu và gọi nghiệp vụ.
- `service`: xử lý quy tắc nghiệp vụ và transaction.
- `repository`: truy vấn database, không xử lý UI/HTTP.
- `entity`: ánh xạ bảng và quan hệ JPA.
- `dto`: dữ liệu API của chức năng, không phải entity database.
- `staff/view/StaffViews`: ánh xạ các bản ghi thành dữ liệu workspace cá nhân.
- Chỉ tạo các thư mục cần dùng; chức năng không có service không cần thư mục service rỗng.
- Kiểm thử nằm trong cùng package tương ứng ở `src/test/java/com/cafehr`.
- Khi chuyển package phải cập nhật cả import và test; chạy `mvnw clean test` để loại class cũ khỏi `target`.

Các controller hiện có vẫn giữ nguyên trách nhiệm và đường dẫn API. `BranchManagerController` tập hợp thao tác trong phạm vi chi nhánh; các entity/repository mà nó sử dụng nằm trong chức năng sở hữu dữ liệu tương ứng.

## Flutter

```text
hrm_app/lib/
├── main.dart                     # Điểm vào ngắn, gọi bootstrap()
├── app/
│   ├── app.dart                  # MaterialApp, theme, locale, màn hình đầu
│   └── bootstrap.dart            # Khởi tạo Dio, repository và Bloc
├── core/
│   ├── config/api_config.dart    # API_BASE_URL và mặc định theo thiết bị
│   ├── network/api_error.dart    # Chuẩn hóa lỗi mạng
│   ├── services/                 # GPS và thông tin thiết bị
│   └── theme/                    # Màu sắc, kiểu chữ, ThemeData
├── features/
│   ├── admin/                    # Không gian Admin
│   ├── attendance/               # Model/repository/use case chấm công
│   ├── auth/                     # Login, Google, liên kết tài khoản
│   ├── branch/                   # Không gian Manager, chọn vị trí chi nhánh
│   ├── home/                     # Trang chấm công tổng quát tương thích
│   ├── schedule/                 # Model lịch, use case, thanh chọn tuần
│   └── staff/                    # Không gian Staff và các form/yêu cầu
└── shared/
    ├── data/
    │   ├── models/               # ApiResponse
    │   └── remote/               # Retrofit ApiClient dùng chung
    └── presentation/
        ├── models/               # Dữ liệu dashboard dùng cho nhiều vai trò
        └── widgets/              # Shell, card, badge, form, danh sách
```

Trong mỗi feature, dùng các lớp khi cần:

```text
features/staff/
├── data/repositories/
└── presentation/
    ├── cubit/
    ├── dialogs/
    ├── helpers/
    ├── screens/
    ├── tabs/
    └── widgets/
```

- `data`: model API, adapter, triển khai repository và tích hợp SDK.
- `domain`: hợp đồng repository và use case hiện có.
- `presentation`: giao diện, state, form và widget của chức năng.
- `shared`: thành phần thực sự dùng ở nhiều feature; không gom tất cả widget vào đây.
- `core`: cấu hình và hạ tầng chung. Màn hình đọc API config trực tiếp, không import `main.dart`.
- `ApiClient` hiện chứa nhiều nhóm API nên đặt ở `shared/data/remote`. Đây là nơi tích hợp chung, không thuộc riêng Admin hay Staff.
- Import giữa các file Dart của app dùng `package:hrm_app/...`; file sinh mã vẫn giữ `part`/`part of` bên cạnh file nguồn.
- File `*.g.dart` đi cùng model/API tương ứng. Sửa file nguồn rồi chạy build_runner khi thay đổi serialization/API; không sửa tay logic trong file sinh.
- `test/features/<feature>` chứa test theo chức năng; `test/presentation` chứa kiểm thử giao diện chung; fixture dùng chung ở `test/support`.

## Dữ liệu, công cụ và file sinh

| Vị trí | Mục đích |
|---|---|
| `src/main/resources/db/` | SQL nâng cấp được Spring chạy khi khởi động |
| `scripts/database/` | SQL chạy chủ động, ví dụ thêm nhân viên demo |
| `database/backups/` | Bản xuất database |
| `tools/password/` | Công cụ Java độc lập tạo BCrypt cho dữ liệu mẫu |
| `docs/` | Tài liệu nghiệp vụ, cấu trúc và cách chạy |
| `target/` | Class, báo cáo test, JAR Maven tự sinh |
| `hrm_app/build/` | APK, ảnh preview, kết quả build Flutter |
| `hrm_app/.dart_tool/` | Cache và cấu hình do Dart sinh |

Không đặt mã nguồn cần giữ trong `target/` hoặc `build/`: các thư mục này bị xóa khi chạy clean và không được Git theo dõi. Công cụ `DemoPassword.java` đã chuyển sang `tools/password/`.

## Đường dẫn đã đổi thường dùng

| Trước | Hiện tại |
|---|---|
| `com.cafehr.controller` | `<feature>.controller`, ví dụ `com.cafehr.schedule.controller` |
| `com.cafehr.entity` | `<feature>.entity`, ví dụ `com.cafehr.user.entity` |
| `com.cafehr.dto` | `<feature>.dto`; `ApiResponse` ở `common.dto` |
| `com.cafehr.service` | `<feature>.service`; `StaffViews` ở `staff.view` |
| `lib/presentation/screens/employee` | `lib/features/staff/presentation` |
| `lib/presentation/screens/branch` | `lib/features/branch/presentation` |
| `lib/presentation/screens/admin` | `lib/features/admin/presentation` |
| `lib/presentation/widgets` | `lib/shared/presentation/widgets` hoặc widget của feature |
| `hrm_appdata.sql` | `database/backups/hrm_appdata.sql` |
| `scripts/seed-demo-staff.sql` | `scripts/database/seed-demo-staff.sql` |
| `target/seed-tools/DemoPassword.java` | `tools/password/DemoPassword.java` |
