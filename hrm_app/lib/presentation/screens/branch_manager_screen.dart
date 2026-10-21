import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/login_response.dart';
import '../../main.dart';
import '../blocs/branch/branch_cubit.dart';
import '../widgets/app_shell.dart';
import 'branch/branch_helpers.dart';
import 'branch/tabs/branch_overview_tab.dart';
import 'branch/dialogs/branch_schedule_sheet.dart';
import 'branch/dialogs/branch_staff_sheets.dart';
import 'branch/dialogs/branch_request_decision_dialog.dart';
import 'branch/tabs/branch_attendance_tab.dart';
import 'branch/tabs/branch_reports_tab.dart';
import 'branch/tabs/branch_requests_tab.dart';
import 'branch/tabs/branch_schedule_tab.dart';
import 'branch/tabs/branch_staff_tab.dart';
import 'login_screen.dart';

class BranchManagerScreen extends StatefulWidget {
  final LoginResponse loginResponse;
  const BranchManagerScreen({super.key, required this.loginResponse});
  @override
  State<BranchManagerScreen> createState() => _BranchManagerScreenState();
}

class _BranchManagerScreenState extends State<BranchManagerScreen> {
  late final Dio _dio;
  late final BranchCubit _cubit;
  int _index = 0;
  String _period = 'Week', _requestFilter = 'Pending', _staffQuery = '';
  DateTime _scheduleDate = DateUtils.dateOnly(DateTime.now());
  DateTime _attendanceDate = DateUtils.dateOnly(DateTime.now());
  DateTime _reportFrom = DateUtils.dateOnly(
    DateTime.now().subtract(const Duration(days: 6)),
  );
  DateTime _reportTo = DateUtils.dateOnly(DateTime.now());
  DateTime get _from => _period == 'Day'
      ? _scheduleDate
      : _period == 'Month'
      ? DateTime(_scheduleDate.year, _scheduleDate.month, 1)
      : _scheduleDate.subtract(Duration(days: _scheduleDate.weekday - 1));
  DateTime get _to => _period == 'Day'
      ? _scheduleDate
      : _period == 'Month'
      ? DateTime(_scheduleDate.year, _scheduleDate.month + 1, 0)
      : _from.add(const Duration(days: 6));
  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        baseUrl: globalBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Authorization': 'Bearer ${widget.loginResponse.token}'},
      ),
    );
    _cubit = BranchCubit(_dio);
    _reload();
  }

  @override
  void dispose() {
    _cubit.close();
    _dio.close();
    super.dispose();
  }

  Future<void> _schedules() => _cubit.fetch('schedules', '/manager/schedules', {
    'from': BranchHelpers.dateToYmd(_from),
    'to': BranchHelpers.dateToYmd(_to),
  });
  Future<void> _attendance() => _cubit.fetch(
    'attendance',
    '/manager/attendance',
    {'date': BranchHelpers.dateToYmd(_attendanceDate)},
  );
  Future<void> _report() => _cubit.fetch('report', '/manager/reports', {
    'from': BranchHelpers.dateToYmd(_reportFrom),
    'to': BranchHelpers.dateToYmd(_reportTo),
  });
  Future<void> _reload() async {
    await Future.wait([
      _cubit.fetch('branch', '/manager/branch'),
      _cubit.fetch('shifts', '/manager/shifts'),
      _schedules(),
      _attendance(),
      _cubit.fetch('requests', '/manager/requests'),
      _report(),
      _dashboard(),
    ]);
  }

  Future<void> _dashboard() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    await Future.wait([
      _cubit.fetch('dashboardAttendance', '/manager/attendance', {
        'date': BranchHelpers.dateToYmd(today),
      }),
      _cubit.fetch('dashboardSchedules', '/manager/schedules', {
        'from': BranchHelpers.dateToYmd(monday),
        'to': BranchHelpers.dateToYmd(monday.add(const Duration(days: 6))),
      }),
    ]);
  }

  Future<void> _openSchedule() => BranchScheduleSheet.show(
    context,
    staff: _cubit.state.staff,
    shifts: _cubit.state.shifts,
    schedules: (_cubit.state.resources['dashboardSchedules'] as List? ?? [])
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList(),
    initialDate: DateUtils.dateOnly(DateTime.now()),
    onSend: _cubit.send,
    onReload: _reload,
    showMessage: _message,
    cleanError: BranchCubit.cleanError,
    onPickDate: _pickDate,
  );
  Future<void> _openStaff() => BranchStaffFormSheet.show(
    context,
    onSend: _cubit.send,
    onReload: _reload,
    showMessage: _message,
    cleanError: BranchCubit.cleanError,
  );
  Future<void> _publish(Map<String, dynamic> schedule) async {
    try {
      await _cubit.send('POST', '/manager/schedules/${schedule['id']}/publish');
      await _reload();
      _message('Đã công bố ca làm.');
    } catch (e) {
      _message(BranchCubit.cleanError(e), isError: true);
    }
  }

  Future<void> _approve(Map<String, dynamic> request) =>
      BranchRequestDecisionDialog.show(
        context,
        request: request,
        approved: true,
        onConfirm: (note) async {
          await _cubit.send(
            'PUT',
            '/manager/requests/${request['id']}',
            data: {'status': 'APPROVED', if (note != null) 'managerNote': note},
          );
          await _reload();
          _message('Đã duyệt yêu cầu.');
        },
      );
  void _navigate(int index) {
    setState(() {
      _index = index;
      if (index == 2) _attendanceDate = DateUtils.dateOnly(DateTime.now());
      if (index == 1) {
        _period = 'Week';
        _scheduleDate = DateUtils.dateOnly(DateTime.now());
      }
    });
    if (index == 2) _attendance();
    if (index == 1) _schedules();
  }

  void _message(String text, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    DateTime? firstDate,
    DateTime? lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (value != null && mounted) onPicked(value);
  }

  Future<void> _reportRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _reportFrom, end: _reportTo),
    );
    if (range == null || !mounted) return;
    if (range.duration.inDays > 92) {
      _message('Chọn khoảng thời gian tối đa 3 tháng.', isError: true);
      return;
    }
    setState(() {
      _reportFrom = range.start;
      _reportTo = range.end;
    });
    await _report();
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn muốn kết thúc phiên quản lý?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await const FlutterSecureStorage().delete(key: 'jwt_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<BranchCubit, BranchState>(
    bloc: _cubit,
    builder: (context, state) {
      final resource = [
        'dashboardAttendance',
        'schedules',
        'attendance',
        'requests',
        'branch',
        'report',
      ][_index];
      final attendance = state.attendanceData;
      final requests = state.resources['requests'] is List
          ? (state.resources['requests'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      return AppShell(
        title: state.branch['name']?.toString() ?? 'Quản lý chi nhánh',
        subtitle:
            '${state.branch['code'] ?? 'HRM Cafe'} · ${widget.loginResponse.name}',
        selectedIndex: _index,
        onDestinationSelected: _navigate,
        destinations: [
          const AppDestination('Tổng quan', Icons.dashboard_outlined),
          const AppDestination('Phân ca', Icons.calendar_month_outlined),
          const AppDestination('Chấm công', Icons.fact_check_outlined),
          AppDestination(
            'Yêu cầu',
            Icons.mail_outline,
            count: requests.where((e) => e['status'] == 'PENDING').length,
          ),
          const AppDestination('Đội ngũ', Icons.people_outline),
          const AppDestination('Báo cáo', Icons.insights_outlined),
        ],
        onRefresh: () => _reload(),
        onLogout: _logout,
        refreshing: state.loading.isNotEmpty,
        error:
            state.errors[resource] ??
            state.errors['branch'] ??
            (_index == 0 ? state.errors['dashboardSchedules'] : null) ??
            (_index == 1 ? state.errors['shifts'] : null),
        child: IndexedStack(
          index: _index,
          children: [
            BranchOverviewTab(
              name: widget.loginResponse.name,
              state: state,
              onRefresh: _reload,
              onNavigate: _navigate,
              onAssignShift: _openSchedule,
              onAddStaff: _openStaff,
              onPublish: _publish,
              onApprove: _approve,
            ),

            BranchScheduleTab(
              schedules: state.schedules,
              staff: state.staff,
              shifts: state.shifts,
              schedulePeriod: _period,
              selectedDate: _scheduleDate,
              scheduleFrom: _from,
              scheduleTo: _to,
              onPeriodChanged: (value) async {
                setState(() => _period = value);
                await _schedules();
              },
              onDateChanged: (value) async {
                setState(() => _scheduleDate = value);
                await _schedules();
              },
              onSend: _cubit.send,
              onReloadSchedules: () async {
                await _schedules();
                await _dashboard();
              },
              showMessage: _message,
              cleanError: BranchCubit.cleanError,
              onPickDate: _pickDate,
            ),
            BranchAttendanceTab(
              attendance: state.attendance,
              total: (attendance['total'] as num?)?.toInt() ?? 0,
              checkedIn: (attendance['checkedIn'] as num?)?.toInt() ?? 0,
              checkedOut: (attendance['checkedOut'] as num?)?.toInt() ?? 0,
              absent: (attendance['absent'] as num?)?.toInt() ?? 0,
              selectedDate: _attendanceDate,
              onDateChanged: (value) async {
                setState(() => _attendanceDate = value);
                await _attendance();
              },
              onPickDate: _pickDate,
              onRefresh: _attendance,
            ),
            BranchRequestsTab(
              requests: requests,
              requestFilter: _requestFilter,
              onFilterChanged: (value) =>
                  setState(() => _requestFilter = value),
              onSend: _cubit.send,
              onReloadRequests: _reload,
              showMessage: _message,
              cleanError: BranchCubit.cleanError,
            ),
            BranchStaffTab(
              staff: state.staff,
              branch: state.branch,
              staffQuery: _staffQuery,
              onQueryChanged: (value) => setState(() => _staffQuery = value),
              onViewShifts: () => setState(() => _index = 1),
              onSend: _cubit.send,
              onReload: _reload,
              showMessage: _message,
              cleanError: BranchCubit.cleanError,
            ),
            BranchReportsTab(
              report: state.report,
              staffCount: state.staff.length,
              reportFrom: _reportFrom,
              reportTo: _reportTo,
              onSelectReportRange: _reportRange,
            ),
          ],
        ),
      );
    },
  );
}
