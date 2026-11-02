import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/features/auth/data/models/login_response.dart';
import 'package:hrm_app/shared/data/remote/api_client.dart';
import 'package:hrm_app/core/config/api_config.dart';
import 'package:hrm_app/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:hrm_app/features/admin/data/attendance_report_exporter.dart';
import 'package:hrm_app/features/admin/presentation/screens/attendance_report_screen.dart';
import 'package:hrm_app/shared/presentation/widgets/app_shell.dart';
import 'package:hrm_app/features/admin/presentation/dialogs/store_form_dialog.dart';
import 'package:hrm_app/features/admin/presentation/dialogs/branch_closure_dialog.dart';
import 'package:hrm_app/features/admin/presentation/dialogs/user_form_dialog.dart';
import 'package:hrm_app/features/admin/presentation/tabs/admin_accounts_tab.dart';
import 'package:hrm_app/features/admin/presentation/tabs/admin_attendance_tab.dart';
import 'package:hrm_app/features/admin/presentation/tabs/admin_branches_tab.dart';
import 'package:hrm_app/features/admin/presentation/tabs/admin_overview_tab.dart';
import 'package:hrm_app/features/admin/presentation/tabs/admin_schedule_tab.dart';
import 'package:hrm_app/features/auth/presentation/screens/login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final LoginResponse loginResponse;
  const AdminHomeScreen({super.key, required this.loginResponse});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late final Dio _dio;
  late final AdminCubit _cubit;
  int _index = 0;
  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Authorization': 'Bearer ${widget.loginResponse.token}'},
      ),
    );
    _cubit = AdminCubit(ApiClient(_dio, baseUrl: globalBaseUrl))..load();
  }

  @override
  void dispose() {
    _cubit.close();
    _dio.close();
    super.dispose();
  }

  void _message(String text, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _store({Map<String, dynamic>? store}) => StoreFormDialog.show(
    context,
    store: store,
    users: _cubit.state.users,
    locationService: LocationService(),
    showSnackBar: _message,
    onSubmit: (data) async {
      await _cubit.save(
        () => store == null
            ? _cubit.api.createStore(data)
            : _cubit.api.updateStore(store['id'], data),
      );
      _message('Đã lưu thông tin chi nhánh.');
    },
  );
  void _user() => UserFormDialog.show(
    context,
    stores: _cubit.state.stores,
    showSnackBar: _message,
    onSubmit: (data) async {
      await _cubit.save(() => _cubit.api.createUser(data));
      _message('Đã tạo tài khoản.');
    },
  );
  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _delete(int id, String name) async {
    if (!await _confirm(
      'Xóa vĩnh viễn chi nhánh trống?',
      '$name chỉ được xóa khi chưa có nhân sự hoặc lịch sử. Xác nhận xóa?',
    )) {
      return;
    }
    try {
      await _cubit.save(() => _cubit.api.deleteStore(id));
      _message('Đã xóa chi nhánh.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _placement({
    Map<String, dynamic>? store,
    Map<String, dynamic>? employee,
  }) async {
    final saved = await BranchClosureDialog.show(
      context,
      dio: _dio,
      stores: _cubit.state.stores,
      store: store,
      employee: employee,
    );
    if (saved == true && mounted) {
      await _cubit.load();
      _message(
        store == null
            ? 'Đã cập nhật bố trí nhân sự.'
            : 'Đã ngừng hoạt động chi nhánh và xử lý nhân sự.',
      );
    }
  }

  Future<void> _reset(int id, String name) async {
    if (!await _confirm(
      'Đặt lại thiết bị?',
      '$name sẽ có thể đăng nhập bằng thiết bị mới.',
    )) {
      return;
    }
    try {
      await _cubit.save(() => _cubit.api.resetDevice(id));
      _message('Đã đặt lại liên kết thiết bị.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _logout() async {
    if (!await _confirm('Đăng xuất?', 'Bạn muốn kết thúc phiên quản trị?')) {
      return;
    }
    await const FlutterSecureStorage().delete(key: 'jwt_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _exportAttendance() async {
    final exporter = AttendanceReportExporter(_dio);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceReportScreen(
          users: _cubit.state.users,
          stores: _cubit.state.stores,
          onLoad: exporter.loadSummary,
          onExport: (request, format) =>
              exporter.export(request, format: format),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AdminCubit, AdminState>(
    bloc: _cubit,
    builder: (context, state) => AppShell(
      title: 'Quản trị hệ thống',
      subtitle: 'HRM Cafe · ${widget.loginResponse.name}',
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      destinations: const [
        AppDestination('Tổng quan', Icons.dashboard_outlined),
        AppDestination('Chi nhánh', Icons.storefront_outlined),
        AppDestination('Tài khoản', Icons.people_outline),
        AppDestination('Chấm công', Icons.fact_check_outlined),
        AppDestination('Lịch làm', Icons.calendar_month_outlined),
      ],
      onRefresh: () => _cubit.load(),
      onLogout: _logout,
      refreshing: state.loading,
      error: state.error,
      child: !state.initialized && state.loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _index,
              children: [
                AdminOverviewTab(
                  loginResponse: widget.loginResponse,
                  dashboardData: state.dashboard,
                  stores: state.stores,
                  users: state.users,
                  attendance: state.attendance,
                  dataReady: state.initialized,
                  onAddStore: () => _store(),
                  onAddUser: _user,
                  onEditStore: (s) => _store(store: s),
                  onNavigate: (i) => setState(() => _index = i),
                  onRefresh: _cubit.load,
                ),
                AdminBranchesTab(
                  stores: state.stores,
                  onRefresh: _cubit.load,
                  onAddStore: () => _store(),
                  onEditStore: (s) => _store(store: s),
                  onDeleteStore: _delete,
                  onCloseStore: (s) => _placement(store: s),
                ),
                AdminAccountsTab(
                  users: state.users,
                  stores: state.stores,
                  onRefresh: _cubit.load,
                  onAddUser: _user,
                  onResetDevice: _reset,
                  onPlacement: (u) => _placement(employee: u),
                ),
                AdminAttendanceTab(
                  attendanceList: state.attendance,
                  onRefresh: _cubit.load,
                  onExport: state.initialized ? _exportAttendance : null,
                ),
                AdminScheduleTab(dio: _dio, stores: state.stores),
              ],
            ),
    ),
  );
}
