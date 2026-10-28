# Ngừng hoạt động chi nhánh và điều chuyển nhân sự

## Thao tác trong app

**Admin → Chi nhánh → menu chi nhánh → Ngừng hoạt động và xử lý nhân sự**.

1. App tải danh sách Staff/Manager, số ca sắp tới, yêu cầu đang chờ và người chưa check-out.
2. Admin nhập lý do, chọn cách xử lý cho tất cả Staff/Manager. Có thể áp dụng cùng cách xử lý cho cả nhóm rồi chọn chi nhánh nhận riêng cho từng người.
3. Chọn một trong ba cách: điều chuyển sang chi nhánh đang hoạt động; chờ điều chuyển; ngừng làm việc.
4. Với Manager chuyển nơi làm, quyền ở chi nhánh cũ kết thúc. Mặc định chuyển thành Staff; Admin có thể chọn bổ nhiệm làm Manager nếu nơi nhận chưa có Manager.
5. Kiểm tra thông tin và đánh dấu xác nhận. Backend kiểm tra lại toàn bộ trước khi thực hiện trong một transaction.

Nếu còn ca chưa check-out, hệ thống chặn đóng chi nhánh và hiển thị người cần xử lý. Nếu thiếu phương án, chi nhánh nhận hết chỗ hoặc đã có Manager, toàn bộ thao tác bị từ chối.

Tài khoản Admin có liên kết với chi nhánh sẽ được gỡ liên kết, giữ quyền Admin và tiếp tục sử dụng. Chúng không nằm trong danh sách ngừng làm việc/điều chuyển.

**Admin → Tài khoản → menu nhân viên → Điều chuyển / trạng thái làm việc** dùng cùng quy tắc cho từng người. Có thể tiếp nhận nhân viên chờ điều chuyển hoặc kích hoạt lại người đã ngừng làm việc bằng cách điều chuyển đến nơi làm mới.

## Trạng thái nhân viên

| Trạng thái | Đăng nhập/xem lịch sử | Phân ca/check-in | Chi nhánh |
|---|---|---|---|
| `ACTIVE` | Có | Khi đủ điều kiện ca làm | Chi nhánh đang hoạt động |
| `WAITING_TRANSFER` | Có | Không | Chưa được bố trí |
| `INACTIVE` | Không | Không | Không còn trực thuộc |

Đăng nhập bằng mật khẩu và Google đều kiểm tra trạng thái. JWT đã cấp cũng bị chặn khi tài khoản chuyển sang `INACTIVE`. Quyền trong request lấy lại từ database nên token Manager cũ không tiếp tục truy cập API Manager sau khi đổi vai trò.

Staff đang chờ điều chuyển thấy thông báo trên trang chủ và vẫn đọc được lịch sử, thông báo cá nhân.

## Lịch và yêu cầu

- Ca có trạng thái `PENDING` hoặc `ON_LEAVE` còn thời gian làm việc sẽ chuyển sang `CANCELLED`, không xóa bản ghi.
- Các ca cũ được hủy khi thay đổi nơi làm; Manager tại nơi nhận phân lịch mới. Không tự chuyển ca sang địa điểm khác.
- Ca đã chấm công phải được xử lý trước khi thay đổi bố trí nhân sự.
- Yêu cầu đang chờ của chi nhánh và các yêu cầu đổi ca liên quan người được điều chuyển sẽ bị hủy, kèm ghi chú và thông báo.
- Yêu cầu đã xử lý và chấm công lịch sử được giữ nguyên. Nghỉ đã được duyệt vẫn được kiểm tra theo nhân viên khi phân lịch mới.
- Ca hủy không gây trùng lịch và không được cộng vào tổng giờ phân công hoặc thống kê vắng mặt.
- Luồng điều chuyển qua `PUT /api/admin/users/{id}` và bổ nhiệm Manager cũng dùng quy tắc giữ lịch sử/hủy ca cũ.

## Giữ chi nhánh gốc

`user_schedules` và `branch_requests` lưu riêng `store_id`, `store_name`, `store_code` khi tạo. Chấm công xác định chi nhánh qua lịch làm được liên kết.

Các truy vấn lịch, yêu cầu, chấm công và báo cáo của chi nhánh dùng chi nhánh trên bản ghi, không dùng chi nhánh hiện tại của nhân viên. Vì vậy điều chuyển nhân viên không chuyển lịch sử sang báo cáo chi nhánh mới. Màn hình Admin xem chấm công hiển thị/tìm kiếm theo chi nhánh gốc.

`src/main/resources/db/branch-lifecycle.sql` chạy trước JPA để bổ sung cột và backfill dữ liệu cũ theo liên kết chi nhánh còn có trong database ở lần nâng cấp đầu. Dữ liệu lịch sử bị đổi liên kết trước khi có chức năng snapshot không thể tự suy ra lại chi nhánh đã mất.

## Xóa vĩnh viễn

Chỉ chi nhánh trống, không có người trực thuộc, Manager, lịch làm hoặc yêu cầu mới có thể xóa vĩnh viễn. App ẩn thao tác này với chi nhánh có dữ liệu. Backend kiểm tra lại khi nhận lệnh, kể cả client cũ gọi API trực tiếp.

Chi nhánh đã hoạt động có lịch sử được giữ ở trạng thái `CLOSED`. Form chỉnh sửa thông thường không cho đóng chi nhánh đang mở; cần đi qua luồng xử lý nhân sự.

## API

- `GET /api/admin/stores/{id}/closure-preview`: danh sách người cần xử lý, tác động tới lịch/yêu cầu, người đang chấm công.
- `POST /api/admin/stores/{id}/close`: đóng chi nhánh và thực hiện toàn bộ phương án.
- `PUT /api/admin/users/{id}/placement`: điều chuyển hoặc thay đổi trạng thái một nhân viên.
- `DELETE /api/admin/stores/{id}`: chỉ xóa vĩnh viễn chi nhánh chưa có dữ liệu.

Ví dụ body đóng chi nhánh có 3 người:

```json
{
  "reason": "Kết thúc thuê mặt bằng",
  "placements": [
    {"userId": 3, "action": "TRANSFER", "targetStoreId": 2, "manager": false},
    {"userId": 4, "action": "WAITING_TRANSFER", "manager": false},
    {"userId": 5, "action": "INACTIVE", "manager": false}
  ]
}
```

Phải gửi đúng một phương án cho mỗi Staff/Manager còn trực thuộc tại thời điểm xử lý. Chỉ gửi `targetStoreId` và chọn `manager: true` khi dùng `TRANSFER`.

## Kiểm thử

```powershell
.\mvnw.cmd test '-Dstaff.integration=true' '-Dgoogle.integration=true'
cd hrm_app
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

`BranchLifecycleIntegrationTest` dùng fixture riêng và rollback: giữ lịch sử, hủy ca/yêu cầu, điều chuyển nhóm, kiểm tra định biên, ca chưa check-out, Manager, quyền API, khóa tài khoản và xóa chi nhánh trống.

`test/features/branch/branch_closure_test.dart` kiểm tra bố cục điện thoại/desktop/cỡ chữ lớn, xác nhận phương án, chặn ca đang chấm công, lọc nơi nhận và giữ form khi API từ chối.
