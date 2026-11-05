# TÀI LIỆU THIẾT KẾ DATABASE LOCAL & ĐẶC TẢ API - MAPPING GIAO DIỆN (HRM CAFE)

## 📌 TỔNG QUAN HỆ THỐNG
Hệ thống **HRM Manager - Cafe Chain** là giải pháp quản lý nhân sự & chấm công GPS toàn diện cho chuỗi cửa hàng Cafe, bao gồm:
1. **Backend**: Spring Boot 3.2 (Java 17), Hibernate JPA, Spring Security JWT, Microsoft SQL Server.
2. **Frontend Mobile/Web**: Flutter App (Clean Architecture, BLoC/Cubit, Dio REST Client).

---

## 🗄️ 1. THIẾT KẾ DATABASE LOCAL (MICROSOFT SQL SERVER - `CafeHRM`)

### 1.1. Sơ đồ Quan hệ Thực thể (ERD Overview)
- **`stores`** (1) ─── (N) **`users`** (1) ─── (N) **`user_schedules`** (1) ─── (N) **`attendances`**
- **`users`** (1) ─── (N) **`branch_requests`**
- **`users`** (1) ─── (N) **`staff_notifications`**
- **`users`** (1) ─── (0..1) **`google_accounts`**
- **`shifts`** (1) ─── (N) **`user_schedules`**

---

### 1.2. Chi tiết Bảng & Trường Dữ liệu (Tables Specification)

#### Bảng 1: `stores` (Chi Nhánh / Cửa Hàng)
Lưu thông tin cửa hàng, định biên nhân sự, tọa độ GPS chấm công & trạng thái hoạt động.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID tự tăng của chi nhánh |
| `code` | `NVARCHAR(50)` | UNIQUE, NOT NULL | Mã chuẩn hóa chi nhánh (VD: `HCM-TD01`) |
| `name` | `NVARCHAR(150)` | NOT NULL | Tên cửa hàng (VD: `Cafe Thủ Đức`) |
| `latitude` | `FLOAT` | NOT NULL | Tọa độ GPS vĩ độ |
| `longitude` | `FLOAT` | NOT NULL | Tọa độ GPS kinh độ |
| `allowed_radius` | `INT` | NOT NULL, DEFAULT 200 | Bán kính chấm công hợp lệ (mét) |
| `max_staff` | `INT` | NOT NULL, DEFAULT 15 | Định biên nhân sự tối đa |
| `status` | `VARCHAR(20)` | NOT NULL, DEFAULT 'ACTIVE' | Trạng thái: `ACTIVE`, `MAINTENANCE`, `CLOSED` |
| `manager_id` | `BIGINT` | FOREIGN KEY (`users.id`), NULLABLE | ID Cửa hàng trưởng (1-1 Manager) |

---

#### Bảng 2: `users` (Tài Khoản & Nhân Viên)
Lưu thông tin tài khoản người dùng, vai trò, thiết bị di động đã liên kết và chi nhánh trực thuộc.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID nhân viên |
| `name` | `NVARCHAR(100)` | NOT NULL | Họ và tên nhân viên |
| `phone` | `VARCHAR(15)` | UNIQUE, NOT NULL | Số điện thoại (dùng làm username đăng nhập) |
| `password` | `VARCHAR(255)` | NOT NULL | Mật khẩu đã mã hóa BCrypt |
| `role` | `VARCHAR(20)` | NOT NULL | Vai trò: `ADMIN`, `MANAGER`, `STAFF` |
| `employment_status` | `VARCHAR(20)` | NOT NULL, DEFAULT 'ACTIVE' | Trạng thái công tác: `ACTIVE`, `SUSPENDED`, `RESIGNED` |
| `device_id` | `VARCHAR(255)` | NULLABLE | ID thiết bị di động gắn chặt với tài khoản |
| `store_id` | `BIGINT` | FOREIGN KEY (`stores.id`), NULLABLE | Chi nhánh nhân viên trực thuộc |

---

#### Bảng 3: `shifts` (Ca Làm Việc)
Lưu danh mục các ca làm việc trong hệ thống.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID ca làm việc |
| `name` | `NVARCHAR(100)` | NOT NULL | Tên ca (VD: `Ca Sáng`, `Ca Chiều`, `Ca Tối`) |
| `start_time` | `TIME(7)` | NOT NULL | Giờ bắt đầu (VD: `07:00:00`) |
| `end_time` | `TIME(7)` | NOT NULL | Giờ kết thúc (VD: `12:00:00`) |

---

#### Bảng 4: `user_schedules` (Lịch Phân Ca Nhân Viên)
Lưu lịch làm việc chi tiết của từng nhân viên theo từng ngày.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID lịch làm việc |
| `user_id` | `BIGINT` | FOREIGN KEY (`users.id`), NOT NULL | ID nhân viên |
| `shift_id` | `BIGINT` | FOREIGN KEY (`shifts.id`), NOT NULL | ID ca làm việc |
| `date` | `DATE` | NOT NULL | Ngày làm việc (`YYYY-MM-DD`) |
| `status` | `VARCHAR(20)` | NOT NULL, DEFAULT 'PENDING' | Trạng thái: `PENDING`, `CHECKED_IN`, `CHECKED_OUT`, `ABSENT` |
| `note` | `NVARCHAR(500)` | NULLABLE | Ghi chú ca làm việc |
| `assigned_by` | `BIGINT` | NULLABLE | ID người phân ca |

---

#### Bảng 5: `attendances` (Nhật Ký Chấm Công GPS)
Lưu dấu vết chấm công GPS thời gian thực khi nhân viên Check-in / Check-out.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID bản ghi chấm công |
| `user_id` | `BIGINT` | FOREIGN KEY (`users.id`), NOT NULL | ID nhân viên |
| `schedule_id` | `BIGINT` | FOREIGN KEY (`user_schedules.id`), NOT NULL | ID ca làm việc tương ứng |
| `check_in_time` | `DATETIME2(6)` | NOT NULL | Thời gian Check-in thực tế |
| `check_out_time` | `DATETIME2(6)` | NULLABLE | Thời gian Check-out thực tế |
| `check_in_lat` | `FLOAT` | NOT NULL | Tọa độ GPS vĩ độ lúc Check-in |
| `check_in_lng` | `FLOAT` | NOT NULL | Tọa độ GPS kinh độ lúc Check-in |

---

#### Bảng 6: `branch_requests` (Đơn Từ Nhân Viên)
Lưu các yêu cầu xin nghỉ phép, đổi ca, bổ sung công của nhân viên.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID đơn |
| `user_id` | `BIGINT` | FOREIGN KEY (`users.id`), NOT NULL | ID nhân viên làm đơn |
| `type` | `VARCHAR(20)` | NOT NULL | Loại đơn: `LEAVE` (Nghỉ phép), `SWAP_SHIFT` (Đổi ca), `MISSING_ATTENDANCE` (Bổ sung công) |
| `start_date` | `DATE` | NOT NULL | Ngày bắt đầu |
| `end_date` | `DATE` | NOT NULL | Ngày kết thúc |
| `reason` | `NVARCHAR(1000)` | NOT NULL | Lý do xin duyệt |
| `status` | `VARCHAR(20)` | NOT NULL, DEFAULT 'PENDING' | Trạng thái: `PENDING`, `APPROVED`, `REJECTED` |
| `manager_note` | `NVARCHAR(1000)` | NULLABLE | Phản hồi từ Quản lý chi nhánh |
| `created_at` | `DATETIME2(6)` | NOT NULL | Thời điểm tạo đơn |

---

#### Bảng 7: `staff_notifications` (Thông Báo Nội Bộ)
Lưu thông báo chi nhánh và thông báo cá nhân gửi tới nhân viên.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID thông báo |
| `user_id` | `BIGINT` | FOREIGN KEY (`users.id`), NOT NULL | ID nhân viên nhận thông báo |
| `title` | `NVARCHAR(200)` | NOT NULL | Tiêu đề thông báo |
| `message` | `NVARCHAR(1000)` | NOT NULL | Nội dung chi tiết |
| `is_read` | `BIT` | NOT NULL, DEFAULT 0 | Trạng thái đã đọc (0: Chưa đọc, 1: Đã đọc) |
| `created_at` | `DATETIME2(6)` | NOT NULL | Thời điểm gửi |
| `created_by` | `BIGINT` | NULLABLE | ID người tạo thông báo |

---

#### Bảng 8: `google_accounts` (Tài Khoản Google Liên Kết)
Lưu thông tin liên kết OAuth2 Google Sign-In với tài khoản nhân viên.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID bản ghi liên kết |
| `user_id` | `BIGINT` | FOREIGN KEY (`users.id`), UNIQUE, NOT NULL | ID nhân viên liên kết |
| `google_id` | `VARCHAR(255)` | UNIQUE, NOT NULL | Sub / ID người dùng Google |
| `email` | `VARCHAR(255)` | NOT NULL | Email Google |
| `avatar_url` | `VARCHAR(500)` | NULLABLE | Ảnh đại diện Google |
| `linked_at` | `DATETIME2(6)` | NOT NULL | Thời điểm liên kết |

---

#### Bảng 9: `system_configs` (Cấu Hình Hệ Thống)
Lưu các tham số cấu hình động toàn hệ thống.

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PRIMARY KEY, IDENTITY | ID cấu hình |
| `config_key` | `VARCHAR(100)` | UNIQUE, NOT NULL | Mã cấu hình (VD: `reminder_minutes`) |
| `config_value` | `NVARCHAR(500)` | NOT NULL | Giá trị cấu hình (VD: `10`) |

---

## 🔗 2. ĐẶC TẢ API VÀ MAPPING GIAO DIỆN (FLUTTER APP)

Base URL: `http://<HOST>:8080/api`  
Xác thực: Bearer Token trong Header `Authorization: Bearer <JWT_TOKEN>`

---

### MODULE 1: ĐĂNG NHẬP & XÁC THỰC (`/api/auth`)

#### 1.1. Đăng nhập bằng Số điện thoại & Mật khẩu
- **Endpoint**: `POST /api/auth/login`
- **Request Body**:
  ```json
  {
    "phone": "0901000003",
    "password": "123456",
    "deviceId": "emulator_device_123"
  }
  ```
- **Response**: `ApiResponse<LoginResponse>` (token, id, name, phone, role, storeId, storeName)
- **Mapping Giao Diện**:
  - **Screen**: `LoginScreen` (`lib/features/auth/presentation/screens/login_screen.dart`)
  - **State Management**: `LoginBloc`
  - **Mô tả UI**: Ô nhập Phone, Password, Nút "Đăng nhập" và Nút Quick Fill tài khoản dùng thử (Admin / Manager / Staff).

#### 1.2. Đăng nhập bằng Google OAuth2
- **Endpoint**: `POST /api/auth/google`
- **Request Body**: `{"idToken": "google_id_token_string"}`
- **Mapping Giao Diện**:
  - **Widget**: `GoogleLoginButton` (`lib/features/auth/presentation/widgets/google_login_button.dart`)
  - **Mô tả UI**: Nút "Đăng nhập bằng Google".

#### 1.3. Liên kết Tài khoản Google
- **Endpoint**: `POST /api/auth/google/link`
- **Request Body**: `{"phone": "0901000003", "password": "123456", "idToken": "google_id_token_string"}`
- **Mapping Giao Diện**:
  - **Dialog**: `GoogleLinkDialog` (`lib/features/auth/presentation/dialogs/google_link_dialog.dart`)
  - **Mô tả UI**: Dialog yêu cầu nhập số điện thoại & mật khẩu để xác nhận liên kết Google với tài khoản có sẵn.

---

### MODULE 2: KHÔNG GIAN LÀM VIỆC NHÂN VIÊN - STAFF (`/api/staff`)

#### 2.1. Lấy thông tin cá nhân Nhân viên
- **Endpoint**: `GET /api/staff/me`
- **Response**: Thông tin chi tiết user (họ tên, SĐT, vai trò, tên chi nhánh).
- **Mapping Giao Diện**:
  - **Screen**: `StaffScreen` (`lib/features/staff/presentation/screens/staff_screen.dart`)
  - **Mô tả UI**: Header hiển thị Chào hỏi nhân viên, tên chi nhánh trực thuộc và Avatar.

#### 2.2. Cập nhật hồ sơ cá nhân
- **Endpoint**: `PUT /api/staff/profile`
- **Request Body**: `{"name": "Lê Văn Staff 1"}`
- **Mapping Giao Diện**:
  - **Dialog**: `StaffProfileForm` (`lib/features/staff/presentation/dialogs/staff_profile_form.dart`)
  - **Mô tả UI**: Form chỉnh sửa họ tên nhân viên.

#### 2.3. Đổi mật khẩu
- **Quyền**: Admin, Manager và Staff tự đổi mật khẩu của chính mình khi còn nhớ mật khẩu hiện tại; không cần Admin phê duyệt và không phụ thuộc xác minh email/SĐT.
- **Endpoint theo role**: `PUT /api/staff/password`, `PUT /api/manager/password`, `PUT /api/admin/profile/password`.
- **Request Body**: `{"currentPassword": "...", "newPassword": "..."}`. Backend kiểm tra mật khẩu hiện tại, từ chối dùng lại mật khẩu cũ và lưu BCrypt.
- **Mapping Giao Diện**:
  - **Đường dẫn**: Profile → Tài khoản và bảo mật → Đổi mật khẩu.
  - **Dialog**: Manager/Staff dùng `AccountProfileForm` (Staff thông qua `StaffProfileForm`); Admin dùng `AdminProfileSectionScreen`.
  - **Quên mật khẩu**: Manager/Staff chọn mục riêng **Quên mật khẩu? → Yêu cầu Admin hỗ trợ** hoặc mở từ đăng nhập. Luồng hỗ trợ không thay thế chức năng tự đổi mật khẩu; không gửi OTP/email đến thông tin chưa xác minh. Tài khoản Admin quên mật khẩu tiếp tục được khôi phục qua quản trị hệ thống ngoài luồng hỗ trợ nhân viên.

#### 2.4. Xem Lịch làm việc cá nhân
- **Endpoint**: `GET /api/staff/schedules`
- **Query Params**: `startDate`, `endDate`
- **Response**: Danh sách ca làm việc được phân trong khoảng thời gian.
- **Mapping Giao Diện**:
  - **Tab**: `StaffScheduleTab` (`lib/features/staff/presentation/tabs/staff_schedule_tab.dart`)
  - **Widget**: `StaffShiftCard` & `ScheduleWeekStrip`
  - **Mô tả UI**: Dải chọn ngày trong tuần, danh sách Card ca làm việc trong ngày (Sáng / Chiều / Tối) kèm giờ bắt đầu - kết thúc.

#### 2.5. Xem danh sách Đơn từ cá nhân
- **Endpoint**: `GET /api/staff/requests`
- **Response**: Danh sách đơn xin nghỉ phép / đổi ca / bổ sung công.
- **Mapping Giao Diện**:
  - **Tab**: `StaffRequestsTab` (`lib/features/staff/presentation/tabs/staff_requests_tab.dart`)
  - **Mô tả UI**: Danh sách các đơn đã gửi kèm Badge trạng thái (Đang chờ / Đã duyệt / Từ chối) và phản hồi từ Manager.

#### 2.6. Tạo Đơn từ mới
- **Endpoint**: `POST /api/staff/requests`
- **Request Body**:
  ```json
  {
    "type": "LEAVE",
    "startDate": "2026-11-10",
    "endDate": "2026-11-10",
    "reason": "Xin nghỉ ốm"
  }
  ```
- **Mapping Giao Diện**:
  - **Dialog**: `StaffRequestForm` (`lib/features/staff/presentation/dialogs/staff_request_form.dart`)
  - **Mô tả UI**: Dropdown chọn loại đơn (Nghỉ phép / Đổi ca / Bổ sung công), chọn ngày bắt đầu - kết thúc, ô nhập lý do.

#### 2.7. Xem Thông báo nội bộ
- **Endpoint**: `GET /api/staff/notifications`
- **Mapping Giao Diện**:
  - **Sheet**: Popup/Sheet Thông báo trên `StaffScreen` (biểu tượng Quả chuông).

---

### MODULE 3: CHẤM CÔNG GPS (`/api/attendance`)

#### 3.1. Lấy lịch làm việc hôm nay để Chấm công
- **Endpoint**: `GET /api/attendance/today-schedules`
- **Response**: Danh sách ca làm việc trong ngày hôm nay.
- **Mapping Giao Diện**:
  - **Screen**: `HomeScreen` (`lib/features/home/presentation/screens/home_screen.dart`)
  - **Widget**: `PersonalAttendanceCard` (`lib/features/attendance/presentation/widgets/personal_attendance_card.dart`)
  - **Mô tả UI**: Card thông tin ca làm việc hiện tại, khoảng cách tới cửa hàng và trạng thái chấm công.

#### 3.2. Thực hiện Check-in (Vào ca)
- **Endpoint**: `POST /api/attendance/check-in`
- **Request Body**:
  ```json
  {
    "scheduleId": 1,
    "lat": 10.8512,
    "lng": 106.7718
  }
  ```
- **Mapping Giao Diện**:
  - **Button**: Nút **"Chấm công vào"** trên `PersonalAttendanceCard`.
  - **Xử lý**: Tự động gọi `LocationService` lấy tọa độ GPS thực tế của thiết bị, kiểm tra bán kính `allowedRadius` của cửa hàng trước khi gửi API.

#### 3.3. Thực hiện Check-out (Ra ca)
- **Endpoint**: `POST /api/attendance/check-out`
- **Request Body**: `{"attendanceId": 12}`
- **Mapping Giao Diện**:
  - **Button**: Nút **"Chấm công ra"** trên `PersonalAttendanceCard`.

#### 3.4. Xem Lịch sử Chấm công
- **Endpoint**: `GET /api/attendance/history`
- **Mapping Giao Diện**:
  - **Tab**: Lịch sử chấm công trên `HomeScreen` / `StaffScreen`.
  - **Mô tả UI**: Danh sách chi tiết thời gian Check-in, Check-out thực tế của từng ngày.

---

### MODULE 4: QUẢN LÝ CHI NHÁNH - MANAGER (`/api/manager` & `/api/requests`)

#### 4.1. Dashboard Tổng quan Chi nhánh
- **Endpoint**: `GET /api/manager/dashboard`
- **Response**: Tỷ lệ đi làm hôm nay, số ca chờ chấm công, số đơn chưa duyệt, thống kê nhân sự.
- **Mapping Giao Diện**:
  - **Screen**: `BranchManagerScreen` (`lib/features/branch/presentation/screens/branch_manager_screen.dart`)
  - **Tab**: `BranchOverviewTab` (`lib/features/branch/presentation/tabs/branch_overview_tab.dart`)
  - **Mô tả UI**: Các Card chỉ số Metric (Tổng nhân sự, Ca làm hôm nay, Đơn cần duyệt), danh sách lối tắt nhanh.

#### 4.2. Quản lý Nhân sự Chi nhánh
- **Endpoint**: `GET /api/manager/staff`
- **Response**: Danh sách nhân viên thuộc chi nhánh quản lý.
- **Mapping Giao Diện**:
  - **Tab**: `BranchStaffTab` (`lib/features/branch/presentation/tabs/branch_staff_tab.dart`)
  - **Mô tả UI**: Danh sách nhân viên, thông tin chức vụ, số điện thoại.

#### 4.3. Thêm / Sửa Nhân viên Chi nhánh
- **Endpoint**: `POST /api/manager/staff` & `PUT /api/manager/staff/{id}`
- **Mật khẩu**: Manager chỉ nhập mật khẩu ban đầu khi tạo tài khoản mới. Khi sửa nhân viên không có ô đổi mật khẩu; API cập nhật từ chối HTTP 403 nếu gửi trường `password`, giữ nguyên mật khẩu và thiết bị liên kết. Nhân viên tự đổi trong Profile bằng mật khẩu hiện tại; nếu quên thì chỉ Admin hỗ trợ đặt lại.
- **Mapping Giao Diện**:
  - **Sheet**: `BranchStaffSheets` (`lib/features/branch/presentation/dialogs/branch_staff_sheets.dart`)

#### 4.4. Quản lý Phân ca Chi nhánh (Shift Roster)
- **Endpoint**: `GET /api/manager/schedules` & `POST /api/manager/schedules`
- **Mapping Giao Diện**:
  - **Tab**: `BranchScheduleTab` (`lib/features/branch/presentation/tabs/branch_schedule_tab.dart`)
  - **Sheet/Dialog**: `BranchScheduleSheet` & `ShiftRosterDialogs`
  - **Mô tả UI**: Bảng phân ca tuần, chọn nhân viên gán vào từng Ca Sáng / Ca Chiều / Ca Tối.

#### 4.5. Phê duyệt Đơn từ Nhân viên
- **Endpoint**: `GET /api/requests/branch` & `POST /api/requests/{id}/decision`
- **Request Body**: `{"approved": true, "managerNote": "Đồng ý cho nghỉ"}`
- **Mapping Giao Diện**:
  - **Tab**: `BranchRequestsTab` (`lib/features/branch/presentation/tabs/branch_requests_tab.dart`)
  - **Dialog**: `BranchRequestDecisionDialog`
  - **Mô tả UI**: Danh sách đơn từ nhân viên gửi lên, nút "Duyệt" (xanh) và "Từ chối" (đỏ) kèm ô nhập ghi chú.

#### 4.6. Gửi Thông báo Chi nhánh
- **Endpoint**: `POST /api/manager/announcements`
- **Mapping Giao Diện**:
  - **Dialog**: `BranchAnnouncementDialog` (`lib/features/branch/presentation/dialogs/branch_announcement_dialog.dart`)

---

### MODULE 5: QUẢN TRỊ HỆ THỐNG - ADMIN (`/api/admin`)

#### 5.1. Dashboard Tổng quan Toàn hệ thống
- **Endpoint**: `GET /api/admin/dashboard`
- **Response**: Thống kê số lượng chi nhánh, tổng nhân sự toàn chuỗi, tổng số ca làm việc.
- **Mapping Giao Diện**:
  - **Screen**: `AdminHomeScreen` (`lib/features/admin/presentation/screens/admin_home_screen.dart`)
  - **Tab**: `AdminOverviewTab` (`lib/features/admin/presentation/tabs/admin_overview_tab.dart`)

#### 5.2. Quản lý Danh mục Chi nhánh (Stores)
- **Endpoint**: `GET /api/admin/stores`, `POST /api/admin/stores`, `PUT /api/admin/stores/{id}`
- **Request Body**:
  ```json
  {
    "code": "HCM-TD01",
    "name": "Cafe Thủ Đức",
    "latitude": 10.8512,
    "longitude": 106.7718,
    "allowedRadius": 200,
    "maxStaff": 15,
    "status": "ACTIVE"
  }
  ```
- **Mapping Giao Diện**:
  - **Tab**: `AdminBranchesTab` (`lib/features/admin/presentation/tabs/admin_branches_tab.dart`)
  - **Dialog**: `StoreFormDialog` (`lib/features/admin/presentation/dialogs/store_form_dialog.dart`)
  - **Widget**: `StoreLocationPicker` (Bản đồ chọn tọa độ GPS chi nhánh).

#### 5.3. Đóng cửa Chi nhánh & Điều phối Nhân sự
- **Endpoint**: `POST /api/admin/branches/{id}/close`
- **Request Body**: Danh sách chuyển nhân viên sang chi nhánh mới (`targetStoreId`).
- **Mapping Giao Diện**:
  - **Dialog**: `BranchClosureDialog` (`lib/features/admin/presentation/dialogs/branch_closure_dialog.dart`)

#### 5.4. Quản lý Tài khoản Toàn hệ thống (Users)
- **Endpoint**: `GET /api/admin/users`, `POST /api/admin/users`, `PUT /api/admin/users/{id}`
- **Mapping Giao Diện**:
  - **Tab**: `AdminAccountsTab` (`lib/features/admin/presentation/tabs/admin_accounts_tab.dart`)
  - **Dialog**: `UserFormDialog` (`lib/features/admin/presentation/dialogs/user_form_dialog.dart`)

#### 5.5. Quản lý Khung Ca & Điều chuyển Ca
- **Endpoint**: `GET /api/admin/roster`, `POST /api/admin/roster/transfer`
- **Mapping Giao Diện**:
  - **Tab**: `AdminScheduleTab` (`lib/features/admin/presentation/tabs/admin_schedule_tab.dart`)
  - **Dialog**: `ShiftTransferDialog` (`lib/features/admin/presentation/dialogs/shift_transfer_dialog.dart`)

#### 5.6. Báo cáo Bảng công & Xuất file
- **Endpoint**: `GET /api/admin/reports/attendance`, `GET /api/admin/reports/attendance/export`
- **Mapping Giao Diện**:
  - **Screen**: `AttendanceReportScreen` (`lib/features/admin/presentation/screens/attendance_report_screen.dart`)
  - **Exporter**: `AttendanceReportExporter` (`lib/features/admin/data/attendance_report_exporter.dart`)
  - **Mô tả UI**: Bộ lọc theo Tháng/Chi nhánh, bảng xem trước tỷ lệ công, nút Xuất Báo Cáo Excel/PDF.

---

## 📑 3. BẢNG TỔNG HỢP MAPPING API ➔ SCREEN FLUTTER

| Chức Năng | API Endpoint | HTTP | Flutter Screen / Component | File Path |
| :--- | :--- | :--- | :--- | :--- |
| **Đăng nhập SĐT** | `/api/auth/login` | POST | `LoginScreen` | `features/auth/presentation/screens/login_screen.dart` |
| **Đăng nhập Google** | `/api/auth/google` | POST | `GoogleLoginButton` | `features/auth/presentation/widgets/google_login_button.dart` |
| **Hồ sơ cá nhân** | `/api/staff/me` | GET | `StaffScreen` | `features/staff/presentation/screens/staff_screen.dart` |
| **Đổi mật khẩu** | `/api/staff/password` | PUT | `StaffProfileForm` | `features/staff/presentation/dialogs/staff_profile_form.dart` |
| **Lịch ca cá nhân** | `/api/staff/schedules` | GET | `StaffScheduleTab` | `features/staff/presentation/tabs/staff_schedule_tab.dart` |
| **Gửi đơn xin nghỉ** | `/api/staff/requests` | POST | `StaffRequestForm` | `features/staff/presentation/dialogs/staff_request_form.dart` |
| **Lấy ca hôm nay** | `/api/attendance/today-schedules`| GET | `PersonalAttendanceCard` | `features/attendance/presentation/widgets/personal_attendance_card.dart` |
| **Chấm công Vào/Ra** | `/api/attendance/check-in` | POST | `PersonalAttendanceCard` | `features/attendance/presentation/widgets/personal_attendance_card.dart` |
| **Lịch sử công** | `/api/attendance/history` | GET | `HomeScreen` | `features/home/presentation/screens/home_screen.dart` |
| **Dashboard Manager**| `/api/manager/dashboard` | GET | `BranchOverviewTab` | `features/branch/presentation/tabs/branch_overview_tab.dart` |
| **Phân ca tuần** | `/api/manager/schedules` | POST | `BranchScheduleTab` | `features/branch/presentation/tabs/branch_schedule_tab.dart` |
| **Duyệt đơn từ** | `/api/requests/{id}/decision` | POST | `BranchRequestsTab` | `features/branch/presentation/tabs/branch_requests_tab.dart` |
| **Dashboard Admin** | `/api/admin/dashboard` | GET | `AdminOverviewTab` | `features/admin/presentation/tabs/admin_overview_tab.dart` |
| **Tạo/Sửa Chi nhánh** | `/api/admin/stores` | POST/PUT | `StoreFormDialog` | `features/admin/presentation/dialogs/store_form_dialog.dart` |
| **Đóng chi nhánh** | `/api/admin/branches/{id}/close` | POST | `BranchClosureDialog` | `features/admin/presentation/dialogs/branch_closure_dialog.dart` |
| **Quản lý Tài khoản**| `/api/admin/users` | GET/POST | `AdminAccountsTab` | `features/admin/presentation/tabs/admin_accounts_tab.dart` |
| **Xuất Báo cáo công** | `/api/admin/reports/attendance` | GET | `AttendanceReportScreen` | `features/admin/presentation/screens/attendance_report_screen.dart` |
