import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/error_handler.dart';
import '../../data/models/login_response.dart';
import '../../data/remote/api_client.dart';
import '../../main.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final LoginResponse loginResponse;

  const AdminHomeScreen({super.key, required this.loginResponse});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ApiClient _apiClient;
  final LocationService _locationService = LocationService();

  bool _isLoading = false;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _stores = [];
  List<dynamic> _users = [];
  List<dynamic> _attendanceList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['Authorization'] =
              'Bearer ${widget.loginResponse.token}';
          return handler.next(options);
        },
      ),
    );

    _apiClient = ApiClient(dio, baseUrl: globalBaseUrl);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final dashRes = await _apiClient.getDashboardSummary();
      final storeRes = await _apiClient.getAllStores();
      final userRes = await _apiClient.getAllUsers();
      final attRes = await _apiClient.getAllAttendance();

      setState(() {
        if (dashRes.success == true) _dashboardData = dashRes.data;
        if (storeRes.success == true) _stores = storeRes.data ?? [];
        if (userRes.success == true) _users = userRes.data ?? [];
        if (attRes.success == true) _attendanceList = attRes.data ?? [];
      });
    } catch (e) {
      final msg = e is DioException
          ? ErrorHandler.parseDioError(e, globalBaseUrl)
          : e.toString().replaceAll('Exception: ', '');
      _showSnackBar('Lỗi tải dữ liệu: $msg', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ================= MODAL THÊM / SỬA CHI NHÁNH & BỔ NHIỆM =================
  void _showStoreDialog({Map<String, dynamic>? store}) {
    final isEditing = store != null;
    final codeCtrl = TextEditingController(text: isEditing ? store['code'] : '');
    final nameCtrl = TextEditingController(text: isEditing ? store['name'] : '');
    final latCtrl =
        TextEditingController(text: isEditing ? '${store['latitude']}' : '10.8512');
    final lngCtrl = TextEditingController(
        text: isEditing ? '${store['longitude']}' : '106.7718');
    final radiusCtrl = TextEditingController(
        text: isEditing ? '${store['allowedRadius']}' : '200');
    final maxStaffCtrl = TextEditingController(
        text: isEditing ? '${store['maxStaff'] ?? 15}' : '15');

    String selectedStatus = isEditing ? (store['status'] ?? 'ACTIVE') : 'ACTIVE';
    int? selectedManagerId = isEditing ? store['managerId'] : null;

    bool fetchingGps = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Cấu Hình Chi Nhánh' : 'Tạo Chi Nhánh Mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Mã Chi Nhánh
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mã Chi Nhánh (Không trùng)',
                    hintText: 'VD: HN-CG01, HCM-Q101',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Tên Chi Nhánh
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên chi nhánh',
                    hintText: 'VD: Cafe Cầu Giấy',
                    prefixIcon: Icon(Icons.store),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Định Biên Nhân Sự (Max Staff)
                TextField(
                  controller: maxStaffCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Định biên nhân sự tối đa (Max Staff)',
                    hintText: 'VD: 15 (cơ sở lớn), 8 (cơ sở nhỏ)',
                    prefixIcon: Icon(Icons.groups),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Trạng Thái Vòng Đời Chi Nhánh
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Trạng Thái Hoạt Động',
                    prefixIcon: Icon(Icons.published_with_changes),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'ACTIVE',
                        child: Text('ACTIVE (Đang hoạt động)',
                            overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'MAINTENANCE',
                        child: Text('MAINTENANCE (Đang bảo trì)',
                            overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'CLOSED',
                        child: Text('CLOSED (Ngừng hoạt động)',
                            overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: 12),

                // 5. Bổ Nhiệm Cửa Hàng Trưởng
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: selectedManagerId,
                  decoration: const InputDecoration(
                    labelText: 'Bổ Nhiệm Cửa Hàng Trưởng',
                    prefixIcon: Icon(Icons.person_pin),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Chưa bổ nhiệm (Để trống)',
                          overflow: TextOverflow.ellipsis),
                    ),
                    ..._users.map((u) => DropdownMenuItem<int?>(
                          value: u['id'],
                          child: Text('${u['name']} (${u['phone']})',
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedManagerId = val);
                  },
                ),
                const SizedBox(height: 12),

                // 6. Tọa Độ GPS & Bán Kính Chấm Công
                TextField(
                  controller: latCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Vĩ độ (Latitude GPS)',
                    prefixIcon: Icon(Icons.my_location),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lngCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Kinh độ (Longitude GPS)',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: fetchingGps
                        ? null
                        : () async {
                            setDialogState(() => fetchingGps = true);
                            try {
                              final pos =
                                  await _locationService.getCurrentPosition();
                              latCtrl.text = pos.latitude.toStringAsFixed(6);
                              lngCtrl.text = pos.longitude.toStringAsFixed(6);
                              _showSnackBar('Đã lấy tọa độ GPS thực tế!');
                            } catch (e) {
                              _showSnackBar('Không thể lấy GPS: $e',
                                  isError: true);
                            } finally {
                              setDialogState(() => fetchingGps = false);
                            }
                          },
                    icon: fetchingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gps_fixed),
                    label: Text(fetchingGps
                        ? 'Đang quét GPS...'
                        : 'Lấy Tọa Độ GPS Hiện Tại'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bán kính chấm công (mét)',
                    hintText: 'VD: 200',
                    prefixIcon: Icon(Icons.radar),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  _showSnackBar('Vui lòng nhập tên chi nhánh', isError: true);
                  return;
                }

                // Cảnh báo nếu thay đổi Cửa hàng trưởng đang có
                if (isEditing &&
                    store['managerId'] != null &&
                    selectedManagerId != store['managerId'] &&
                    selectedManagerId != null) {
                  final confirmChange = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Xác nhận thay Cửa hàng trưởng'),
                      content: Text(
                          'Chi nhánh hiện đang có Cửa hàng trưởng: "${store['managerName']}".\nBạn có muốn thay thế người này bằng Cửa hàng trưởng mới không?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(c, true),
                          style:
                              ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                          child: const Text('Xác nhận'),
                        ),
                      ],
                    ),
                  );

                  if (confirmChange != true) return;
                }

                if (ctx.mounted) Navigator.pop(ctx);
                try {
                  final payload = {
                    'code': codeCtrl.text.trim().toUpperCase(),
                    'name': nameCtrl.text.trim(),
                    'latitude': double.tryParse(latCtrl.text) ?? 10.8512,
                    'longitude': double.tryParse(lngCtrl.text) ?? 106.7718,
                    'allowedRadius': int.tryParse(radiusCtrl.text) ?? 200,
                    'maxStaff': int.tryParse(maxStaffCtrl.text) ?? 15,
                    'status': selectedStatus,
                    'managerId': selectedManagerId,
                  };

                  if (isEditing) {
                    final res =
                        await _apiClient.updateStore(store['id'], payload);
                    if (res.success == true) {
                      _showSnackBar('Cập nhật chi nhánh thành công');
                      _loadAllData();
                    }
                  } else {
                    final res = await _apiClient.createStore(payload);
                    if (res.success == true) {
                      _showSnackBar('Tạo chi nhánh mới thành công');
                      _loadAllData();
                    }
                  }
                } catch (e) {
                  _showSnackBar('Lỗi: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  foregroundColor: Colors.white),
              child: Text(isEditing ? 'Lưu Cấu Hình' : 'Tạo Chi Nhánh'),
            ),
          ],
        ),
      ),
    );
  }

  // ================= XÓA CHI NHÁNH =================
  void _deleteStore(int storeId, String storeName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa chi nhánh'),
        content: Text(
            'Bạn có chắc chắn muốn xóa chi nhánh "$storeName"?\nHệ thống chỉ cho phép xóa khi không còn nhân viên thuộc chi nhánh này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await _apiClient.deleteStore(storeId);
                if (res.success == true) {
                  _showSnackBar('Đã xóa chi nhánh thành công');
                  _loadAllData();
                }
              } catch (e) {
                _showSnackBar('Lỗi xóa chi nhánh: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  // ================= MODAL THÊM TÀI KHOẢN =================
  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');
    String selectedRole = 'STAFF';
    int? selectedStoreId = _stores.isNotEmpty ? _stores.first['id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo Tài Khoản Nhân Viên'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                ),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Mật khẩu (mặc định: 123456)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Phân quyền Role'),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                    DropdownMenuItem(value: 'MANAGER', child: Text('MANAGER')),
                    DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),
                if (_stores.isNotEmpty)
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedStoreId,
                    decoration:
                        const InputDecoration(labelText: 'Gán vào Chi nhánh'),
                    items: _stores
                        .map((s) => DropdownMenuItem<int>(
                              value: s['id'],
                              child: Text('${s['code'] ?? 'CN'} - ${s['name']}',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedStoreId = val);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final res = await _apiClient.createUser({
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'password': passCtrl.text.trim(),
                    'role': selectedRole,
                    'storeId': selectedStoreId,
                  });
                  if (res.success == true) {
                    _showSnackBar('Tạo tài khoản thành công');
                    _loadAllData();
                  }
                } catch (e) {
                  _showSnackBar('Lỗi: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  // ================= RESET THIẾT BỊ =================
  Future<void> _resetDevice(int userId) async {
    try {
      final res = await _apiClient.resetDevice(userId);
      if (res.success == true) {
        _showSnackBar('Đã reset thiết bị cho User #$userId thành công');
        _loadAllData();
      }
    } catch (e) {
      _showSnackBar('Lỗi reset thiết bị: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản Trị Chuỗi (${widget.loginResponse.name})'),
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Tổng Quan'),
            Tab(icon: Icon(Icons.store), text: 'Chi Nhánh'),
            Tab(icon: Icon(Icons.people), text: 'Tài Khoản'),
            Tab(icon: Icon(Icons.access_time), text: 'Chấm Công'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildStoresTab(),
                _buildUsersTab(),
                _buildAttendanceTab(),
              ],
            ),
    );
  }

  // 1. DASHBOARD TAB
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.brown[50],
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings,
                  size: 40, color: Colors.brown),
              title: Text(
                widget.loginResponse.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                  'Quyền: ${widget.loginResponse.role} | Chuỗi Café Toàn Quốc'),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Thống kê Hệ thống',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard(
                  'Tổng Chi Nhánh',
                  '${_dashboardData?['totalStores'] ?? _stores.length}',
                  Icons.storefront,
                  Colors.blue),
              _buildStatCard(
                  'Tổng Nhân Viên',
                  '${_dashboardData?['totalUsers'] ?? _users.length}',
                  Icons.people_alt,
                  Colors.green),
              _buildStatCard(
                  'Lượt Chấm Công',
                  '${_dashboardData?['todayAttendanceCount'] ?? _attendanceList.length}',
                  Icons.fact_check,
                  Colors.orange),
              _buildStatCard('Tổng Ca Làm',
                  '${_dashboardData?['totalShifts'] ?? 3}', Icons.schedule, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('Chuyển Sang Giao Diện Chấm Công Nhân Viên'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(count,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // 2. STORES TAB
  Widget _buildStoresTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStoreDialog(),
        backgroundColor: Colors.brown[800],
        icon: const Icon(Icons.add_business),
        label: const Text('Thêm Chi Nhánh'),
      ),
      body: _stores.isEmpty
          ? const Center(child: Text('Chưa có chi nhánh nào trong hệ thống.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _stores.length,
              itemBuilder: (ctx, idx) {
                final store = _stores[idx];
                final storeId = store['id'];
                final currentCount = store['currentStaffCount'] ?? 0;
                final maxStaff = store['maxStaff'] ?? 15;
                final status = store['status'] ?? 'ACTIVE';

                Color statusColor = status == 'ACTIVE'
                    ? Colors.green
                    : (status == 'MAINTENANCE' ? Colors.orange : Colors.red);
                String statusText = status == 'ACTIVE'
                    ? 'Đang hoạt động'
                    : (status == 'MAINTENANCE'
                        ? 'Bảo trì/Sửa chữa'
                        : 'Ngừng hoạt động');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.brown[800],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                store['code'] ?? 'CN-$storeId',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                store['name'] ?? 'Chi nhánh',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Colors.brown,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                statusText,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: statusColor,
                              padding: EdgeInsets.zero,
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showStoreDialog(store: store);
                                } else if (val == 'delete') {
                                  _deleteStore(storeId, store['name'] ?? '');
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Cấu Hình / Chỉnh Sửa'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Xóa Chi Nhánh'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Cửa Hàng Trưởng
                        Row(
                          children: [
                            const Icon(Icons.person_pin,
                                size: 18, color: Colors.brown),
                            const SizedBox(width: 6),
                            const Text(
                              'Cửa hàng trưởng: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                store['managerName'] ?? 'Chưa bổ nhiệm',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: store['managerName'] != null &&
                                          store['managerName'] != 'Chưa bổ nhiệm'
                                      ? Colors.brown[900]
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Định biên nhân sự
                        Row(
                          children: [
                            const Icon(Icons.groups,
                                size: 18, color: Colors.brown),
                            const SizedBox(width: 6),
                            Text(
                              'Định biên nhân sự: $currentCount / $maxStaff người',
                              style: TextStyle(
                                color: currentCount >= maxStaff
                                    ? Colors.red
                                    : Colors.black87,
                                fontWeight: currentCount >= maxStaff
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (currentCount >= maxStaff)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Text('(Đã đạt Max)',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Tọa độ GPS & Bán kính
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 18, color: Colors.brown),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'GPS: ${store['latitude']}, ${store['longitude']} (Bán kính: ${store['allowedRadius']}m)',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // 3. USERS TAB
  Widget _buildUsersTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: Colors.brown[800],
        icon: const Icon(Icons.person_add),
        label: const Text('Tạo Tài Khoản'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _users.length,
        itemBuilder: (ctx, idx) {
          final user = _users[idx];
          final role = user['role'] ?? 'STAFF';
          Color roleColor = role == 'ADMIN'
              ? Colors.red
              : (role == 'MANAGER' ? Colors.orange : Colors.green);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: roleColor,
                child: Text(role[0],
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text('${user['name']} (${user['phone']})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'Vai trò: $role | Chi nhánh: ${user['storeName'] ?? 'Chưa gán'}\nDevice ID: ${user['deviceId'] ?? 'Chưa khóa'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'reset') {
                    _resetDevice(user['id']);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.phonelink_erase, color: Colors.brown),
                        SizedBox(width: 8),
                        Text('Reset Thiết Bị'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 4. ATTENDANCE TAB
  Widget _buildAttendanceTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _attendanceList.length,
      itemBuilder: (ctx, idx) {
        final att = _attendanceList[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.access_time_filled, color: Colors.brown),
            title: Text('${att['userName']} - ${att['shiftName']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Vào: ${att['checkInTime'] ?? 'N/A'}\nRa: ${att['checkOutTime'] ?? 'Chưa check-out'}\nTọa độ: ${att['checkInLat']}, ${att['checkInLng']}'),
            trailing: Chip(
              label: Text(att['status'] ?? 'COMPLETED',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
              backgroundColor: att['status'] == 'CHECKED_IN'
                  ? Colors.green
                  : Colors.blue,
            ),
          ),
        );
      },
    );
  }
}
