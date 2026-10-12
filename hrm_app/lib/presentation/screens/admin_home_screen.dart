import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

  bool _isLoading = false;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _stores = [];
  List<dynamic> _users = [];
  List<dynamic> _attendanceList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize ApiClient instance
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Attach JWT token interceptor
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
      _showSnackBar('Lỗi tải dữ liệu: ${e.toString()}', isError: true);
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

  // ================= MODAL THÊM CHI NHÁNH =================
  void _showAddStoreDialog() {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '10.8512');
    final lngCtrl = TextEditingController(text: '106.7718');
    final radiusCtrl = TextEditingController(text: '200');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Chi Nhánh Mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên chi nhánh'),
              ),
              TextField(
                controller: latCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Vĩ độ (Lat)'),
              ),
              TextField(
                controller: lngCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kinh độ (Lng)'),
              ),
              TextField(
                controller: radiusCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Bán kính cho phép (mét)'),
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
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final res = await _apiClient.createStore({
                  'name': nameCtrl.text.trim(),
                  'latitude': double.tryParse(latCtrl.text) ?? 10.8512,
                  'longitude': double.tryParse(lngCtrl.text) ?? 106.7718,
                  'allowedRadius': int.tryParse(radiusCtrl.text) ?? 200,
                });
                if (res.success == true) {
                  _showSnackBar('Thêm chi nhánh thành công');
                  _loadAllData();
                }
              } catch (e) {
                _showSnackBar('Lỗi: $e', isError: true);
              }
            },
            child: const Text('Tạo'),
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
                    initialValue: selectedStoreId,
                    decoration:
                        const InputDecoration(labelText: 'Gán vào Chi nhánh'),
                    items: _stores
                        .map((s) => DropdownMenuItem<int>(
                              value: s['id'],
                              child: Text(s['name'] ?? 'Chi nhánh'),
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
                  _showSnackBar('Lỗi: $e', isError: true);
                }
              },
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
        onPressed: _showAddStoreDialog,
        backgroundColor: Colors.brown[800],
        icon: const Icon(Icons.add),
        label: const Text('Thêm Chi Nhánh'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _stores.length,
        itemBuilder: (ctx, idx) {
          final store = _stores[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.brown,
                  child: Icon(Icons.store, color: Colors.white)),
              title: Text(store['name'] ?? 'Chi nhánh',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'Tọa độ: ${store['latitude']}, ${store['longitude']}\nBán kính chấm công: ${store['allowedRadius']}m'),
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
