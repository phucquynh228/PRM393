import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/data/models/login_response.dart';
import 'package:hrm_app/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/presentation/blocs/branch/branch_cubit.dart';
import 'package:hrm_app/presentation/models/dashboard_summary.dart';
import 'package:hrm_app/presentation/screens/admin/tabs/admin_overview_tab.dart';
import 'package:hrm_app/presentation/screens/branch/tabs/branch_overview_tab.dart';
import 'package:hrm_app/presentation/widgets/app_shell.dart';
import 'package:hrm_app/presentation/widgets/personal_attendance_card.dart';

import 'support/fakes.dart';
import 'visual_smoke_test.dart' as qa;

final today = DateTime.now();
String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
final current = isoDay(today);
final records = <Map<String, dynamic>>[
  {
    'id': 42,
    'scheduleId': 7,
    'userName': 'Nguyễn Minh Anh',
    'shiftName': 'Ca sáng',
    'checkInTime': '${current}T07:00:00',
    'checkOutTime': null,
    'status': 'CHECKED_IN',
  },
  {
    'id': 43,
    'scheduleId': 8,
    'userName': 'Trần Hoàng Nam',
    'shiftName': 'Ca sáng',
    'checkInTime': '${current}T07:10:00',
    'checkOutTime': '${current}T11:00:00',
    'status': 'CHECKED_OUT',
  },
  {
    'id': null,
    'userName': 'Phạm Thảo Nguyên',
    'shiftName': 'Ca chiều',
    'checkInTime': null,
    'checkOutTime': null,
    'status': 'NOT_CHECKED_IN',
  },
  {
    'id': null,
    'userName': 'Lê Hoài An',
    'shiftName': 'Ca sáng',
    'checkInTime': null,
    'checkOutTime': null,
    'status': 'ABSENT',
  },
];
final stores = <Map<String, dynamic>>[
  {
    'id': 1,
    'name': 'Cafe Thảo Điền',
    'managerId': 2,
    'managerName': 'Nguyễn Minh Anh',
    'status': 'ACTIVE',
    'currentStaffCount': 12,
    'maxStaff': 15,
  },
  {
    'id': 2,
    'name': 'Cafe Phú Nhuận',
    'managerId': null,
    'status': 'ACTIVE',
    'currentStaffCount': 8,
    'maxStaff': 12,
  },
];
final state = BranchState(
  resources: {
    'branch': {
      'name': 'Cafe Thảo Điền',
      'maxStaff': 15,
      'staff': [
        {'id': 3, 'name': 'Minh Anh'},
      ],
    },
    'shifts': [
      {'id': 1, 'name': 'Ca sáng'},
    ],
    'dashboardAttendance': {
      'total': 4,
      'checkedIn': 2,
      'checkedOut': 1,
      'absent': 1,
      'records': records,
    },
    'dashboardSchedules': [
      {
        'id': 7,
        'userId': 3,
        'userName': 'Nguyễn Minh Anh',
        'shiftName': 'Ca sáng',
        'date': current,
        'startTime': '07:00',
        'endTime': '12:00',
        'published': true,
      },
      {
        'id': 8,
        'userId': 4,
        'userName': 'Trần Hoàng Nam',
        'shiftName': 'Ca chiều',
        'date': current,
        'startTime': '12:00',
        'endTime': '17:00',
        'published': false,
      },
    ],
    'requests': [
      {
        'id': 1,
        'userName': 'Thảo Nguyên',
        'type': 'LEAVE',
        'startDate': current,
        'endDate': current,
        'reason': 'Xin nghỉ để tham dự kỳ thi cuối kỳ.',
        'status': 'PENDING',
      },
    ],
  },
);
List<AppDestination> get managerDestinations => const [
  AppDestination('Tổng quan', Icons.dashboard_outlined),
  AppDestination('Phân ca', Icons.calendar_month_outlined),
  AppDestination('Chấm công', Icons.fact_check_outlined),
  AppDestination('Yêu cầu', Icons.mail_outline, count: 1),
  AppDestination('Đội ngũ', Icons.people_outline),
  AppDestination('Báo cáo', Icons.insights_outlined),
];
Widget wrap(
  Widget child,
  FakeAttendanceRepository repo, {
  bool manager = false,
}) => RepositoryProvider<AttendanceRepository>.value(
  value: repo,
  child: AppShell(
    title: manager ? 'Cafe Thảo Điền' : 'Quản trị hệ thống',
    subtitle: 'HRM Cafe · Nguyễn Minh Anh',
    selectedIndex: 0,
    onDestinationSelected: (_) {},
    onLogout: () {},
    destinations: manager
        ? managerDestinations
        : const [
            AppDestination('Tổng quan', Icons.dashboard_outlined),
            AppDestination('Chi nhánh', Icons.storefront_outlined),
            AppDestination('Tài khoản', Icons.people_outline),
            AppDestination('Chấm công', Icons.fact_check_outlined),
          ],
    child: child,
  ),
);
AdminOverviewTab admin({VoidCallback? onAdd, ValueChanged<int>? onNavigate}) =>
    AdminOverviewTab(
      loginResponse: LoginResponse(
        token: 'test',
        userId: 1,
        name: 'Minh Anh',
        role: 'ADMIN',
      ),
      dashboardData: const {'totalStores': 2, 'totalUsers': 24},
      stores: stores,
      users: const [
        {'id': 1, 'role': 'STAFF', 'storeId': 1},
      ],
      attendance: records,
      onRefresh: () async {},
      onAddStore: onAdd ?? () {},
      onAddUser: () {},
      onNavigate: onNavigate ?? (_) {},
      onEditStore: (_) {},
    );
BranchOverviewTab manager({
  VoidCallback? onAssign,
  Future<void> Function(Map<String, dynamic>)? onPublish,
}) => BranchOverviewTab(
  name: 'Minh Anh',
  state: state,
  onRefresh: () async {},
  onNavigate: (_) {},
  onAssignShift: onAssign ?? () {},
  onAddStaff: () {},
  onPublish: onPublish ?? (_) async {},
  onApprove: (_) async {},
);

void main() {
  setUpAll(() async {
    await (FontLoader(
      'HRMSans',
    )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test('today attendance excludes historical and unstarted records', () {
    final rows = attendanceOnDate([
      ...records,
      {'checkInTime': '2000-01-01T08:00:00'},
    ], today);
    expect(rows.length, 2);
    expect(rows.where((r) => r['checkOutTime'] == null).length, 1);
  });
  test('manager reads backend records and keeps compatibility with items', () {
    final data = BranchState(
      resources: {
        'attendance': {'records': records},
      },
    );
    expect(data.attendance.length, 4);
    expect(branchAttendanceRecords({'items': records}).length, 4);
  });
  for (final config in [
    ('admin-dashboard-phone', false, const Size(390, 844), 1.0),
    ('admin-dashboard-desktop', false, const Size(1600, 1150), 1.0),
    ('manager-dashboard-phone', true, const Size(390, 844), 1.0),
    ('manager-dashboard-desktop', true, const Size(1600, 1150), 1.0),
    ('manager-dashboard-small-text', true, const Size(320, 740), 1.5),
    ('admin-dashboard-small-text', false, const Size(320, 740), 1.5),
  ]) {
    testWidgets(config.$1, (tester) async {
      await qa.preview(
        tester,
        wrap(
          config.$2 ? manager() : admin(),
          FakeAttendanceRepository(),
          manager: config.$2,
        ),
        config.$3,
        config.$1,
        scale: config.$4,
      );
      if (find.byType(PersonalAttendanceCard).evaluate().isEmpty) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.byType(PersonalAttendanceCard), findsOneWidget);
      expect(find.text('Check-out ngay'), findsOneWidget);
    });
  }
  testWidgets('admin shortcuts open create and attendance in one tap', (
    tester,
  ) async {
    int created = 0, selected = -1;
    await qa.preview(
      tester,
      wrap(
        admin(onAdd: () => created++, onNavigate: (i) => selected = i),
        FakeAttendanceRepository(),
      ),
      const Size(1440, 1000),
      'admin-dashboard-actions',
    );
    await tester.tap(find.text('Thêm chi nhánh'));
    expect(created, 1);
    await tester.tap(find.text('Xem chấm công'));
    expect(selected, 3);
  });
  testWidgets(
    'manager assigns directly and publishes draft without repeat submissions',
    (tester) async {
      int assigned = 0, published = 0;
      final gate = Completer<void>();
      await qa.preview(
        tester,
        wrap(
          manager(
            onAssign: () => assigned++,
            onPublish: (_) async {
              published++;
              await gate.future;
            },
          ),
          FakeAttendanceRepository(),
          manager: true,
        ),
        const Size(1440, 1200),
        'manager-dashboard-actions',
      );
      await tester.tap(find.text('Phân ca mới'));
      expect(assigned, 1);
      await tester.scrollUntilVisible(
        find.text('Công bố ca'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Công bố ca'));
      await tester.pump();
      expect(published, 1);
      expect(find.text('Đang xử lý…'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Công bố ca'), findsOneWidget);
    },
  );
  testWidgets('check out is available inline and uses real attendance id', (
    tester,
  ) async {
    final repo = FakeAttendanceRepository();
    await qa.preview(
      tester,
      wrap(admin(), repo),
      const Size(390, 844),
      'inline-checkout',
    );
    await tester.ensureVisible(find.text('Check-out ngay'));
    await tester.tap(find.text('Check-out ngay'));
    await tester.pumpAndSettle();
    expect(repo.checkoutCalls, [42]);
    expect(find.text('Đã chấm công ra ca.'), findsOneWidget);
  });
  testWidgets('six manager sections fit mobile and more opens team directly', (
    tester,
  ) async {
    int selected = -1;
    await qa.preview(
      tester,
      AppShell(
        title: 'Chi nhánh',
        subtitle: 'Quản lý',
        selectedIndex: 0,
        onDestinationSelected: (i) => selected = i,
        onLogout: () {},
        destinations: managerDestinations,
        child: const SizedBox(),
      ),
      const Size(390, 844),
      'manager-mobile-navigation',
    );
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đội ngũ'));
    await tester.pumpAndSettle();
    expect(selected, 4);
  });
}
