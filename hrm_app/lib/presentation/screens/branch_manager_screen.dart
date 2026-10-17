import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../data/models/login_response.dart';
import '../../main.dart';
import 'login_screen.dart';

const _coffee = Color(0xFF4E342E);
const _coffeeLight = Color(0xFF795548);
const _cream = Color(0xFFFFF8F4);
const _card = Color(0xFFFFF1E9);

class BranchManagerScreen extends StatefulWidget {
  final LoginResponse loginResponse;

  const BranchManagerScreen({super.key, required this.loginResponse});

  @override
  State<BranchManagerScreen> createState() => _BranchManagerScreenState();
}

class _BranchManagerScreenState extends State<BranchManagerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final Dio _dio;
  final _searchController = TextEditingController();
  final _requestNoteController = TextEditingController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _branch;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _requests = [];
  int _attendanceTotal = 0;
  int _attendanceCheckedIn = 0;
  int _attendanceCheckedOut = 0;
  int _attendanceAbsent = 0;
  Map<String, dynamic> _report = {};
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  DateTime _reportFrom = DateUtils.dateOnly(
    DateTime.now().subtract(const Duration(days: 6)),
  );
  DateTime _reportTo = DateUtils.dateOnly(DateTime.now());
  String _schedulePeriod = 'Tuần';
  String _requestFilter = 'Chờ duyệt';
  String _staffQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _dio = Dio(
      BaseOptions(
        baseUrl: globalBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Authorization': 'Bearer ${widget.loginResponse.token}'},
      ),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _requestNoteController.dispose();
    _dio.close();
    super.dispose();
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      final body = response.data;
      if (body is Map && body['success'] == false) {
        throw Exception(body['message']?.toString() ?? 'Yêu cầu thất bại');
      }
      return body is Map ? body['data'] : null;
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map ? body['message'] : null;
      throw Exception(
        message?.toString() ?? error.message ?? 'Không thể kết nối máy chủ',
      );
    }
  }

  Future<dynamic> _send(String method, String path, {Object? data}) async {
    try {
      final response = await _dio.request(
        path,
        data: data,
        options: Options(method: method),
      );
      final body = response.data;
      if (body is Map && body['success'] == false) {
        throw Exception(body['message']?.toString() ?? 'Yêu cầu thất bại');
      }
      return body is Map ? body['data'] : null;
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map ? body['message'] : null;
      throw Exception(
        message?.toString() ?? error.message ?? 'Không thể kết nối máy chủ',
      );
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final branch = await _get('/manager/branch');
      final shifts = await _get('/manager/shifts');
      if (branch is! Map) {
        throw Exception('Không nhận được thông tin chi nhánh');
      }
      final branchData = Map<String, dynamic>.from(branch);
      final staff = _asMapList(branchData['staff']);
      if (!mounted) return;
      setState(() {
        _branch = branchData;
        _staff = staff;
        _shifts = _asMapList(shifts);
      });
      await Future.wait([
        _loadSchedules(),
        _loadAttendance(),
        _loadRequests(),
        _loadReport(),
      ]);
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime get _scheduleFrom {
    if (_schedulePeriod == 'Ngày') return _selectedDate;
    if (_schedulePeriod == 'Tháng') {
      return DateTime(_selectedDate.year, _selectedDate.month);
    }
    final monday = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - DateTime.monday),
    );
    return DateUtils.dateOnly(monday);
  }

  DateTime get _scheduleTo {
    if (_schedulePeriod == 'Ngày') return _selectedDate;
    if (_schedulePeriod == 'Tháng') {
      return DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    }
    return _scheduleFrom.add(const Duration(days: 6));
  }

  Future<void> _loadSchedules() async {
    final data = await _get('/manager/schedules', {
      'from': _date(_scheduleFrom),
      'to': _date(_scheduleTo),
    });
    if (mounted) setState(() => _schedules = _asMapList(data));
  }

  Future<void> _loadAttendance() async {
    final data = await _get('/manager/attendance', {
      'date': _date(_selectedDate),
    });
    if (data is Map && mounted) {
      setState(() {
        _attendance = _asMapList(data['records']);
        _attendanceTotal = (data['total'] as num?)?.toInt() ?? 0;
        _attendanceCheckedIn = (data['checkedIn'] as num?)?.toInt() ?? 0;
        _attendanceCheckedOut = (data['checkedOut'] as num?)?.toInt() ?? 0;
        _attendanceAbsent = (data['absent'] as num?)?.toInt() ?? 0;
      });
    }
  }

  Future<void> _loadRequests() async {
    final data = await _get('/manager/requests');
    if (mounted) setState(() => _requests = _asMapList(data));
  }

  Future<void> _loadReport() async {
    final data = await _get('/manager/reports', {
      'from': _date(_reportFrom),
      'to': _date(_reportTo),
    });
    if (data is Map && mounted) {
      setState(() => _report = Map<String, dynamic>.from(data));
    }
  }

  Future<void> _refresh() async {
    try {
      await _loadAll();
      if (_error == null) _message('Đã cập nhật dữ liệu');
    } catch (error) {
      _message(_cleanError(error), isError: true);
    }
  }

  void _message(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade800 : _coffee,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? successMessage,
    Future<void> Function()? reload,
  }) async {
    try {
      await action();
      if (reload != null) await reload();
      if (successMessage != null) _message(successMessage);
    } catch (error) {
      _message(_cleanError(error), isError: true);
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
  }) async {
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _coffee),
        ),
        child: child!,
      ),
    );
    if (value != null) onPicked(DateUtils.dateOnly(value));
  }

  @override
  Widget build(BuildContext context) {
    final branchName = _branch?['name']?.toString() ?? 'Chi nhánh';
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _coffee,
        foregroundColor: Colors.white,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(branchName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Xin chào, ${widget.loginResponse.name}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            ),
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: const Color(0xFFFFD54F),
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFFFD54F),
          tabs: const [
            Tab(icon: Icon(Icons.groups_2_outlined), text: 'Nhân sự'),
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Lịch ca'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Chấm công'),
            Tab(
              icon: Icon(Icons.mark_email_unread_outlined),
              text: 'Duyệt đơn',
            ),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Báo cáo'),
          ],
        ),
      ),
      body: _loading && _branch == null
          ? const Center(child: CircularProgressIndicator(color: _coffee))
          : _error != null && _branch == null
          ? _errorView()
          : TabBarView(
              controller: _tabs,
              children: [
                _staffTab(),
                _scheduleTab(),
                _attendanceTab(),
                _requestsTab(),
                _reportsTab(),
              ],
            ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 54, color: _coffeeLight),
          const SizedBox(height: 14),
          const Text(
            'Không tải được dữ liệu chi nhánh',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );

  Widget _page({required Widget child, Widget? fab}) => Scaffold(
    backgroundColor: _cream,
    floatingActionButton: fab,
    body: RefreshIndicator(color: _coffee, onRefresh: _refresh, child: child),
  );

  Widget _heading(String title, String subtitle, {Widget? trailing}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _coffee,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.brown.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
      if (trailing != null) trailing,
    ],
  );

  Widget _staffTab() {
    final query = _staffQuery.trim().toLowerCase();
    final filtered = _staff.where((staff) {
      return staff['name'].toString().toLowerCase().contains(query) ||
          staff['phone'].toString().toLowerCase().contains(query);
    }).toList();
    return _page(
      fab: FloatingActionButton.extended(
        onPressed: _showStaffForm,
        backgroundColor: _coffee,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm nhân viên'),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          _heading(
            'Đội ngũ chi nhánh',
            '${_staff.length} / ${_branch?['maxStaff'] ?? '—'} nhân sự',
            trailing: _surfaceIcon(
              Icons.people_alt_outlined,
              '${_staff.length}',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _staffQuery = value),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc số điện thoại',
              prefixIcon: const Icon(Icons.search, color: _coffeeLight),
              suffixIcon: _staffQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _staffQuery = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _empty('Không tìm thấy nhân viên', Icons.person_search_outlined)
          else
            ...filtered.map(_staffCard),
        ],
      ),
    );
  }

  Widget _staffCard(Map<String, dynamic> staff) {
    final initial = staff['name'].toString().trim().isEmpty
        ? '?'
        : staff['name'].toString().trim()[0].toUpperCase();
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFF1E4DC)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => _showStaffDetails(staff),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFE0CC),
          foregroundColor: _coffee,
          child: Text(
            initial,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          staff['name']?.toString() ?? 'Nhân viên',
          style: const TextStyle(fontWeight: FontWeight.w700, color: _coffee),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 7,
            runSpacing: 5,
            children: [
              _pill(
                staff['phone']?.toString() ?? 'Chưa có SĐT',
                Icons.phone_outlined,
              ),
              _pill(
                staff['deviceId'] == null
                    ? 'Chưa liên kết thiết bị'
                    : 'Đã liên kết',
                staff['deviceId'] == null
                    ? Icons.phonelink_off
                    : Icons.phonelink_lock,
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Chỉnh sửa hồ sơ',
          onPressed: () => _showStaffForm(staff: staff),
          icon: const Icon(Icons.edit_outlined, color: _coffeeLight),
        ),
      ),
    );
  }

  void _showStaffDetails(Map<String, dynamic> staff) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                staff['name']?.toString() ?? 'Nhân viên',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _coffee,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow(
                Icons.phone_outlined,
                'Số điện thoại',
                staff['phone']?.toString() ?? '—',
              ),
              _detailRow(
                Icons.store_outlined,
                'Chi nhánh',
                _branch?['name']?.toString() ?? '—',
              ),
              _detailRow(
                Icons.phonelink_outlined,
                'Thiết bị',
                staff['deviceId'] == null ? 'Chưa liên kết' : 'Đã liên kết',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _tabs.animateTo(1);
                    setState(() => _staffQuery = staff['name'].toString());
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Xem lịch phân ca'),
                  style: FilledButton.styleFrom(backgroundColor: _coffee),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, color: _coffeeLight, size: 20),
        const SizedBox(width: 10),
        Text('$title: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Future<void> _showStaffForm({Map<String, dynamic>? staff}) async {
    final name = TextEditingController(text: staff?['name']?.toString() ?? '');
    final phone = TextEditingController(
      text: staff?['phone']?.toString() ?? '',
    );
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final editing = staff != null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editing ? 'Cập nhật hồ sơ' : 'Thêm nhân viên',
                    style: const TextStyle(
                      fontSize: 21,
                      color: _coffee,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _formField(
                    name,
                    'Họ và tên',
                    Icons.person_outline,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập họ tên'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _formField(
                    phone,
                    'Số điện thoại',
                    Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value == null ||
                            !RegExp(r'^[0-9+() -]{8,15}$')
                                .hasMatch(value.trim())
                        ? 'Số điện thoại không hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _formField(
                    password,
                    editing ? 'Mật khẩu mới (không bắt buộc)' : 'Mật khẩu',
                    Icons.lock_outline,
                    obscure: true,
                    validator: (value) =>
                        !editing && (value == null || value.trim().length < 6)
                        ? 'Mật khẩu tối thiểu 6 ký tự'
                        : null,
                  ),
                  if (!editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        'Bỏ trống mật khẩu để dùng mật khẩu mặc định 123456.',
                        style: TextStyle(
                          color: Colors.brown.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _coffee,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final body = <String, dynamic>{
                          'name': name.text.trim(),
                          'phone': phone.text.trim(),
                          if (password.text.trim().isNotEmpty)
                            'password': password.text.trim(),
                        };
                        try {
                          await _send(
                            editing ? 'PUT' : 'POST',
                            editing
                                ? '/manager/staff/${staff['id']}'
                                : '/manager/staff',
                            data: body,
                          );
                          if (context.mounted) Navigator.pop(context);
                          await _loadAll();
                          _message(
                            editing
                                ? 'Đã cập nhật hồ sơ nhân viên'
                                : 'Đã thêm nhân viên vào chi nhánh',
                          );
                        } catch (error) {
                          _message(_cleanError(error), isError: true);
                          setSheetState(() {});
                        }
                      },
                      child: Text(editing ? 'Lưu thay đổi' : 'Tạo hồ sơ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    password.dispose();
  }

  Widget _formField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _coffeeLight),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  Widget _scheduleTab() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _schedules) {
      (grouped[item['date']?.toString() ?? ''] ??= []).add(item);
    }
    return _page(
      fab: FloatingActionButton.extended(
        onPressed: _shifts.isEmpty || _staff.isEmpty
            ? null
            : () => _showScheduleForm(),
        backgroundColor: _coffee,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Phân ca'),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          _heading('Lịch làm việc', 'Tạo lịch theo ngày, tuần hoặc tháng'),
          const SizedBox(height: 14),
          _periodPicker(),
          const SizedBox(height: 10),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.date_range, color: _coffee),
              title: Text(
                _schedulePeriod == 'Ngày'
                    ? _prettyDate(_selectedDate)
                    : '${_prettyDate(_scheduleFrom)} — ${_prettyDate(_scheduleTo)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Chạm để chọn ngày'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickDate(
                initial: _selectedDate,
                firstDate: DateTime.now(),
                onPicked: (value) async {
                  setState(() => _selectedDate = value);
                  await _loadSchedules();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_schedules.isEmpty)
            _empty(
              'Chưa có ca làm trong khoảng thời gian này',
              Icons.event_busy_outlined,
            )
          else
            ...grouped.entries.map(
              (entry) => _scheduleDateGroup(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  Widget _periodPicker() => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: 'Ngày', label: Text('Ngày')),
      ButtonSegment(value: 'Tuần', label: Text('Tuần')),
      ButtonSegment(value: 'Tháng', label: Text('Tháng')),
    ],
    selected: {_schedulePeriod},
    onSelectionChanged: (selection) async {
      setState(() => _schedulePeriod = selection.first);
      await _loadSchedules();
    },
    style: SegmentedButton.styleFrom(
      foregroundColor: _coffee,
      selectedForegroundColor: Colors.white,
      selectedBackgroundColor: _coffee,
    ),
  );

  Widget _scheduleDateGroup(String date, List<Map<String, dynamic>> items) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
              child: Text(
                _prettyDate(DateTime.tryParse(date) ?? _selectedDate),
                style: const TextStyle(
                  color: _coffee,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...items.map(_scheduleCard),
          ],
        ),
      );

  Widget _scheduleCard(Map<String, dynamic> item) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 5, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: item['published'] == true ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['userName']?.toString() ?? 'Nhân viên',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _coffee,
                  ),
                ),
                Text(
                  '${item['shiftName']} • ${item['startTime']}–${item['endTime']}',
                  style: TextStyle(color: Colors.brown.shade500, fontSize: 13),
                ),
                const SizedBox(height: 3),
                _statusBadge(
                  item['published'] == true ? 'Đã công bố' : 'Bản nháp',
                  item['published'] == true ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
          if (item['published'] != true)
            IconButton(
              tooltip: 'Công bố lịch',
              onPressed: () => _runAction(
                () async {
                  await _send(
                    'POST',
                    '/manager/schedules/${item['id']}/publish',
                  );
                },
                successMessage: 'Đã công bố lịch cho nhân viên',
                reload: _loadSchedules,
              ),
              icon: const Icon(Icons.campaign_outlined, color: Colors.green),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showScheduleForm(schedule: item);
              } else if (value == 'delete') {
                _confirmDeleteSchedule(item);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Sửa lịch')),
              PopupMenuItem(value: 'delete', child: Text('Xóa lịch')),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _showScheduleForm({Map<String, dynamic>? schedule}) async {
    if (_staff.isEmpty || _shifts.isEmpty) {
      _message('Cần có nhân viên và ca làm trước khi phân ca', isError: true);
      return;
    }
    int selectedStaff =
        schedule?['userId'] as int? ?? _staff.first['id'] as int;
    int selectedShift =
        schedule?['shiftId'] as int? ?? _shifts.first['id'] as int;
    DateTime selected =
        DateTime.tryParse(schedule?['date']?.toString() ?? '') ?? _selectedDate;
    bool saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> showDuplicateScheduleDialog() {
            final staffName = _staff
                .firstWhere((item) => item['id'] == selectedStaff)['name']
                .toString();
            final shiftName = _shifts
                .firstWhere((item) => item['id'] == selectedShift)['name']
                .toString();
            return showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Lịch bị trùng'),
                content: Text(
                  '$staffName đã được phân $shiftName vào ngày ${_prettyDate(selected)}.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Đã hiểu'),
                  ),
                ],
              ),
            );
          }

          Future<void> saveSchedule({required bool publish}) async {
            if (saving) return;
            final isDuplicate = _schedules.any((item) {
              return item['userId'] == selectedStaff &&
                  item['shiftId'] == selectedShift &&
                  item['date']?.toString() == _date(selected) &&
                  item['id'] != schedule?['id'];
            });
            if (isDuplicate) {
              await showDuplicateScheduleDialog();
              return;
            }

            setSheetState(() => saving = true);
            try {
              await _send(
                schedule == null ? 'POST' : 'PUT',
                schedule == null
                    ? '/manager/schedules'
                    : '/manager/schedules/${schedule['id']}',
                data: {
                  'userId': selectedStaff,
                  'shiftId': selectedShift,
                  'date': _date(selected),
                  'published': publish,
                },
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              await _loadSchedules();
              _message(
                publish
                    ? 'Đã lưu và công bố lịch'
                    : 'Đã lưu lịch ở trạng thái bản nháp',
              );
            } catch (error) {
              final message = _cleanError(error);
              if (!context.mounted) return;
              if (message.contains('đã được phân ca')) {
                await showDuplicateScheduleDialog();
              } else {
                _message(message, isError: true);
              }
            } finally {
              if (context.mounted) setSheetState(() => saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule == null ? 'Phân ca mới' : 'Chỉnh sửa ca',
                  style: const TextStyle(
                    fontSize: 21,
                    color: _coffee,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedStaff,
                  decoration: _dropdownDecoration('Nhân viên'),
                  items: _staff
                      .map(
                        (person) => DropdownMenuItem<int>(
                          value: person['id'] as int,
                          child: Text(
                            person['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(
                    () => selectedStaff = value ?? selectedStaff,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedShift,
                  decoration: _dropdownDecoration('Ca làm'),
                  items: _shifts
                      .map(
                        (shift) => DropdownMenuItem<int>(
                          value: shift['id'] as int,
                          child: Text(
                            '${shift['name']} (${shift['startTime']}–${shift['endTime']})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(
                    () => selectedShift = value ?? selectedShift,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.calendar_today, color: _coffee),
                  title: const Text('Ngày làm việc'),
                  subtitle: Text(_prettyDate(selected)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _pickDate(
                    initial: selected,
                    firstDate: DateTime.now(),
                    onPicked: (value) => setSheetState(() => selected = value),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _coffee,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: saving
                            ? null
                            : () => saveSchedule(publish: false),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Lưu nháp'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _coffee,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: saving
                            ? null
                            : () => saveSchedule(publish: true),
                        icon: const Icon(Icons.publish_outlined),
                        label: const Text('Lưu & công bố'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Lịch nháp chỉ hiển thị cho nhân viên sau khi được công bố.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.brown.shade400, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  Future<void> _confirmDeleteSchedule(Map<String, dynamic> schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch làm?'),
        content: Text(
          'Xóa ca ${schedule['shiftName']} của ${schedule['userName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        () async => _send('DELETE', '/manager/schedules/${schedule['id']}'),
        successMessage: 'Đã xóa lịch',
        reload: _loadSchedules,
      );
    }
  }

  Widget _attendanceTab() {
    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _heading(
            'Theo dõi chấm công',
            'Tình hình check-in / check-out của chi nhánh',
            trailing: IconButton.filledTonal(
              tooltip: 'Chọn ngày',
              onPressed: () => _pickDate(
                initial: _selectedDate,
                onPicked: (value) async {
                  setState(() => _selectedDate = value);
                  await _loadAttendance();
                },
              ),
              icon: const Icon(Icons.calendar_month, color: _coffee),
            ),
          ),
          const SizedBox(height: 14),
          _dateBanner(
            _selectedDate,
            onTap: () => _pickDate(
              initial: _selectedDate,
              onPicked: (value) async {
                setState(() => _selectedDate = value);
                await _loadAttendance();
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _attendanceMetric(
                'Ca đã công bố',
                '$_attendanceTotal',
                Icons.event_available,
                Colors.blue,
              ),
              _attendanceMetric(
                'Đã check-in',
                '$_attendanceCheckedIn',
                Icons.login,
                Colors.green,
              ),
              _attendanceMetric(
                'Đã check-out',
                '$_attendanceCheckedOut',
                Icons.logout,
                Colors.teal,
              ),
              _attendanceMetric(
                'Vắng / chưa vào ca',
                '$_attendanceAbsent',
                Icons.warning_amber_rounded,
                Colors.deepOrange,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _heading('Lượt chấm công', '${_attendance.length} bản ghi'),
          const SizedBox(height: 8),
          if (_attendance.isEmpty)
            _empty(
              'Chưa có lượt chấm công trong ngày này',
              Icons.fact_check_outlined,
            )
          else
            ..._attendance.map(_attendanceCard),
        ],
      ),
    );
  }

  Widget _attendanceCard(Map<String, dynamic> item) {
    final checkedIn = item['checkInTime'] != null;
    final isClosed = item['checkOutTime'] != null;
    final absent = item['status'] == 'ABSENT';
    final state = !checkedIn
        ? (absent ? 'Vắng mặt' : 'Chưa check-in')
        : isClosed
        ? 'Hoàn tất'
        : 'Đang làm';
    final stateColor = !checkedIn
        ? (absent ? Colors.red : Colors.orange)
        : isClosed
        ? Colors.green
        : Colors.blue;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isClosed
              ? const Color(0xFFE4F3E8)
              : !checkedIn
              ? const Color(0xFFFFE9D2)
              : const Color(0xFFE4EFFA),
          child: Icon(
            isClosed
                ? Icons.check_circle_outline
                : absent
                ? Icons.warning_amber_rounded
                : checkedIn
                ? Icons.more_time
                : Icons.schedule,
            color: stateColor,
          ),
        ),
        title: Text(
          item['userName']?.toString() ?? 'Nhân viên',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${item['shiftName'] ?? 'Ca làm'}\n'
          '${checkedIn ? 'Vào ${_clock(item['checkInTime'])}' : state}  •  '
          'Ra ${isClosed ? _clock(item['checkOutTime']) : 'Chưa checkout'}',
        ),
        isThreeLine: true,
        trailing: _statusBadge(state, stateColor),
      ),
    );
  }

  Widget _attendanceMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) => SizedBox(
    width: (MediaQuery.of(context).size.width - 52) / 2,
    child: _metricCard(label, value, icon, color),
  );

  Widget _requestsTab() {
    final requests = _requests.where((item) {
      if (_requestFilter == 'Tất cả') return true;
      if (_requestFilter == 'Đã xử lý') return item['status'] != 'PENDING';
      return item['status'] == 'PENDING';
    }).toList();
    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
        children: [
          _heading('Duyệt yêu cầu', 'Đơn nghỉ phép và đề nghị đổi ca'),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Chờ duyệt', label: Text('Chờ duyệt')),
              ButtonSegment(value: 'Đã xử lý', label: Text('Đã xử lý')),
              ButtonSegment(value: 'Tất cả', label: Text('Tất cả')),
            ],
            selected: {_requestFilter},
            onSelectionChanged: (value) =>
                setState(() => _requestFilter = value.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: _coffee,
              selectedForegroundColor: Colors.white,
              foregroundColor: _coffee,
            ),
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            _empty(
              _requestFilter == 'Chờ duyệt'
                  ? 'Không có đơn đang chờ duyệt'
                  : 'Chưa có yêu cầu nào',
              Icons.mark_email_read_outlined,
            )
          else
            ...requests.map(_requestCard),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> item) {
    final pending = item['status'] == 'PENDING';
    final leave = item['type'] == 'LEAVE';
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: leave
                      ? const Color(0xFFFFE7D2)
                      : const Color(0xFFE8E7FA),
                  child: Icon(
                    leave ? Icons.beach_access_outlined : Icons.swap_horiz,
                    color: leave ? Colors.deepOrange : Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['userName']?.toString() ?? 'Nhân viên',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        leave ? 'Xin nghỉ phép' : 'Yêu cầu đổi ca',
                        style: TextStyle(
                          color: Colors.brown.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(
                  item['status'] == 'PENDING'
                      ? 'Chờ duyệt'
                      : item['status'] == 'APPROVED'
                      ? 'Đã duyệt'
                      : 'Từ chối',
                  item['status'] == 'PENDING'
                      ? Colors.orange
                      : item['status'] == 'APPROVED'
                      ? Colors.green
                      : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow(
              Icons.event_outlined,
              'Thời gian',
              '${_formatIsoDate(item['startDate'])} — ${_formatIsoDate(item['endDate'])}',
            ),
            Text(
              item['reason']?.toString() ?? '',
              style: const TextStyle(height: 1.4),
            ),
            if ((item['managerNote']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ghi chú: ${item['managerNote']}',
                style: TextStyle(color: Colors.brown.shade500),
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _decideRequest(item, approved: false),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text(
                        'Từ chối',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE9C8C2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _decideRequest(item, approved: true),
                      icon: const Icon(Icons.check),
                      label: const Text('Duyệt đơn'),
                      style: FilledButton.styleFrom(backgroundColor: _coffee),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _decideRequest(
    Map<String, dynamic> request, {
    required bool approved,
  }) async {
    _requestNoteController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? 'Duyệt yêu cầu?' : 'Từ chối yêu cầu?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request['userName']} • ${request['type'] == 'LEAVE' ? 'Xin nghỉ' : 'Đổi ca'}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _requestNoteController,
              maxLength: 1000,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú cho nhân viên (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
            const Text(
              'Duyệt đơn chỉ cập nhật trạng thái. Lịch làm được giữ nguyên để quản lý điều chỉnh thủ công.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approved ? _coffee : Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(approved ? 'Xác nhận duyệt' : 'Xác nhận từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () async {
        await _send(
          'PUT',
          '/manager/requests/${request['id']}',
          data: {
            'status': approved ? 'APPROVED' : 'REJECTED',
            if (_requestNoteController.text.trim().isNotEmpty)
              'managerNote': _requestNoteController.text.trim(),
          },
        );
      },
      successMessage: approved ? 'Đã duyệt yêu cầu' : 'Đã từ chối yêu cầu',
      reload: _loadRequests,
    );
  }

  Widget _reportsTab() {
    final daily = _asMapList(_report['daily']);
    final scheduled = (_report['scheduled'] as num?)?.toInt() ?? 0;
    final attended = (_report['attended'] as num?)?.toInt() ?? 0;
    final rate = (_report['attendanceRate'] as num?)?.toDouble() ?? 0;
    final maxDaily = daily.fold<int>(
      1,
      (max, item) => max > (item['scheduled'] as num? ?? 0)
          ? max
          : (item['scheduled'] as num? ?? 0).toInt(),
    );
    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _heading(
            'Báo cáo chi nhánh',
            'Tổng hợp nhân sự, ca làm và chuyên cần',
          ),
          const SizedBox(height: 14),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.date_range_outlined, color: _coffee),
              title: Text(
                '${_prettyDate(_reportFrom)} — ${_prettyDate(_reportTo)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Chọn khoảng thời gian báo cáo'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _selectReportRange,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _reportMetric(
                'Nhân viên',
                '${_report['staffCount'] ?? _staff.length}',
                Icons.groups_outlined,
                Colors.blue,
              ),
              _reportMetric(
                'Ca đã xếp',
                '$scheduled',
                Icons.event_available,
                Colors.deepPurple,
              ),
              _reportMetric(
                'Có mặt',
                '$attended',
                Icons.how_to_reg,
                Colors.green,
              ),
              _reportMetric(
                'Chuyên cần',
                '${rate.toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _heading('Ca xếp và lượt có mặt', 'Theo từng ngày trong kỳ'),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: daily.isEmpty
                  ? const SizedBox(
                      height: 90,
                      child: Center(child: Text('Chưa có dữ liệu trong kỳ')),
                    )
                  : Column(
                      children: daily.map((day) {
                        final planned = (day['scheduled'] as num? ?? 0).toInt();
                        final done = (day['attended'] as num? ?? 0).toInt();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 58,
                                child: Text(
                                  _shortDate(
                                    DateTime.tryParse(day['date'].toString()) ??
                                        _reportFrom,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.brown.shade500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    _bar(done, maxDaily, Colors.green),
                                    const SizedBox(height: 5),
                                    _bar(
                                      planned,
                                      maxDaily,
                                      const Color(0xFFD7C4BA),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 55,
                                child: Text(
                                  '$done / $planned',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legend(Colors.green, 'Có mặt'),
              const SizedBox(width: 18),
              _legend(const Color(0xFFD7C4BA), 'Ca đã xếp'),
            ],
          ),
          const SizedBox(height: 16),
          _infoBanner(
            'Tỷ lệ chuyên cần = lượt check-in / tổng ca đã xếp. Duyệt đơn nghỉ không tự xóa lịch; vui lòng điều chỉnh ca sau khi duyệt.',
          ),
        ],
      ),
    );
  }

  Future<void> _selectReportRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _reportFrom, end: _reportTo),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _coffee),
        ),
        child: child!,
      ),
    );
    if (range == null) return;
    if (range.duration.inDays > 92) {
      _message('Khoảng báo cáo tối đa 3 tháng', isError: true);
      return;
    }
    setState(() {
      _reportFrom = DateUtils.dateOnly(range.start);
      _reportTo = DateUtils.dateOnly(range.end);
    });
    await _loadReport();
  }

  Widget _bar(int value, int max, Color color) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: max == 0 ? 0 : (value / max).clamp(0.04, 1),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  );

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: Colors.brown.shade500, fontSize: 12)),
    ],
  );

  Widget _reportMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) => SizedBox(
    width: (MediaQuery.of(context).size.width - 42) / 2,
    child: _metricCard(title, value, icon, color),
  );

  Widget _metricCard(String title, String value, IconData icon, Color color) =>
      Card(
        color: _card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.brown.shade500),
              ),
            ],
          ),
        ),
      );

  Widget _surfaceIcon(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: _coffee),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: _coffee, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _pill(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _cream,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _coffeeLight),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.brown.shade600),
        ),
      ],
    ),
  );

  Widget _statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
    ),
  );

  Widget _dateBanner(DateTime date, {required VoidCallback onTap}) => Card(
    color: _card,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: ListTile(
      onTap: onTap,
      leading: const Icon(Icons.calendar_today, color: _coffee),
      title: Text(
        _prettyDate(date),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: const Icon(Icons.keyboard_arrow_down, color: _coffee),
    ),
  );

  Widget _empty(String text, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42),
    child: Column(
      children: [
        Icon(icon, size: 44, color: Colors.brown.shade200),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.brown.shade400),
        ),
      ],
    ),
  );

  Widget _infoBanner(String text) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0D7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: Colors.brown, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade700,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  String _prettyDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  String _formatIsoDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? '—' : _prettyDate(date);
  }

  String _clock(dynamic value) {
    if (value == null) return '—';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
