import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/data/models/login_response.dart';
import 'package:hrm_app/domain/repositories/auth_repository.dart';
import 'package:hrm_app/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/domain/usecases/login_usecase.dart';
import 'package:hrm_app/presentation/blocs/login/login_bloc.dart';
import 'package:hrm_app/presentation/screens/login_screen.dart';
import 'package:hrm_app/presentation/screens/home_screen.dart';
import 'package:hrm_app/presentation/screens/admin/tabs/admin_branches_tab.dart';
import 'package:hrm_app/presentation/screens/admin/dialogs/user_form_dialog.dart';
import 'package:hrm_app/presentation/screens/branch/tabs/branch_schedule_tab.dart';
import 'package:hrm_app/presentation/screens/branch/tabs/branch_reports_tab.dart';
import 'package:hrm_app/presentation/widgets/app_shell.dart';

import 'support/fakes.dart';

class PreviewAuth implements AuthRepository {
  @override
  Future<LoginResponse> login(String phone, String password) async =>
      throw UnimplementedError();
  @override
  Future<bool> isLoggedIn() async => false;
  @override
  Future<void> logout() async {}
}

final _boundary = GlobalKey();
Future<void> preview(
  WidgetTester tester,
  Widget screen,
  Size size,
  String name, {
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(key: _boundary, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  if (const bool.fromEnvironment('CAPTURE_UI')) {
    await tester.runAsync(() async {
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}

Widget managerShell(Widget child, {int selected = 1}) => AppShell(
  title: 'Cafe Thảo Điền',
  subtitle: 'HCM-01 · Nguyễn Minh Anh',
  selectedIndex: selected,
  onDestinationSelected: (_) {},
  onLogout: () {},
  destinations: const [
    AppDestination('Đội ngũ', Icons.people_outline),
    AppDestination('Phân ca', Icons.calendar_month_outlined),
    AppDestination('Chấm công', Icons.fact_check_outlined),
    AppDestination('Yêu cầu', Icons.mail_outline, count: 3),
    AppDestination('Báo cáo', Icons.insights_outlined),
  ],
  child: child,
);

final people = <Map<String, dynamic>>[
  {'id': 1, 'name': 'Nguyễn Minh Anh'},
  {'id': 2, 'name': 'Trần Hoàng Nam'},
  {'id': 3, 'name': 'Phạm Thảo Nguyên'},
];
final schedules = <Map<String, dynamic>>[
  for (int day = 19; day <= 23; day++)
    for (int person = 1; person <= 3; person++)
      {
        'id': day * 10 + person,
        'userId': person,
        'userName': people[person - 1]['name'],
        'shiftId': person == 2 ? 2 : 1,
        'shiftName': person == 2 ? 'Ca chiều' : 'Ca sáng',
        'date': '2026-10-$day',
        'startTime': person == 2 ? '12:00' : '07:00',
        'endTime': person == 2 ? '17:00' : '12:00',
        'published': day <= 21,
        'status': 'PENDING',
      },
];
Future<void> pickDate({
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
  required ValueChanged<DateTime> onPicked,
}) async {}
BranchScheduleTab scheduleTab() => BranchScheduleTab(
  schedules: schedules,
  staff: people,
  shifts: const [
    {'id': 1, 'name': 'Ca sáng', 'startTime': '07:00', 'endTime': '12:00'},
  ],
  schedulePeriod: 'Week',
  selectedDate: DateTime(2026, 10, 20),
  scheduleFrom: DateTime(2026, 10, 19),
  scheduleTo: DateTime(2026, 10, 25),
  onPeriodChanged: (_) {},
  onDateChanged: (_) {},
  onSend: (_, __, {Object? data}) async {},
  onReloadSchedules: () async {},
  showMessage: (_, {bool isError = false}) {},
  cleanError: (e) => '$e',
  onPickDate: pickDate,
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
  for (final config in [
    ('login-phone', const Size(390, 844), 1.0),
    ('login-small-large-text', const Size(320, 740), 1.6),
    ('login-desktop', const Size(1440, 1000), 1.0),
  ]) {
    testWidgets(config.$1, (tester) async {
      final bloc = LoginBloc(loginUseCase: LoginUseCase(PreviewAuth()));
      addTearDown(bloc.close);
      await preview(
        tester,
        BlocProvider.value(value: bloc, child: const LoginScreen()),
        config.$2,
        config.$1,
        scale: config.$3,
      );
    });
  }
  testWidgets('employee-phone', (tester) async {
    final repo = FakeAttendanceRepository();
    await preview(
      tester,
      RepositoryProvider<AttendanceRepository>.value(
        value: repo,
        child: const HomeScreen(name: 'Minh Anh'),
      ),
      const Size(390, 844),
      'employee-phone',
    );
    expect(find.text('Check-out · Kết thúc ca'), findsOneWidget);
    expect(find.text('Check-in · Bắt đầu ca'), findsNothing);
  });
  testWidgets('employee-small-large-text', (tester) async {
    await preview(
      tester,
      RepositoryProvider<AttendanceRepository>.value(
        value: FakeAttendanceRepository(),
        child: const HomeScreen(name: 'Nguyễn Thị Thảo Nguyên'),
      ),
      const Size(320, 740),
      'employee-small-large-text',
      scale: 1.6,
    );
  });
  for (final config in [
    ('manager-phone', const Size(390, 844), 1.0),
    ('manager-small-large-text', const Size(320, 740), 1.5),
    ('manager-week-desktop', const Size(1600, 1000), 1.0),
    ('manager-landscape', const Size(900, 480), 1.5),
  ]) {
    testWidgets(config.$1, (tester) async {
      await preview(
        tester,
        managerShell(scheduleTab()),
        config.$2,
        config.$1,
        scale: config.$3,
      );
    });
  }
  testWidgets('admin-desktop', (tester) async {
    final stores = [
      {
        'id': 1,
        'code': 'HCM-01',
        'name': 'Cafe Thảo Điền',
        'managerName': 'Nguyễn Minh Anh',
        'status': 'ACTIVE',
        'currentStaffCount': 12,
        'maxStaff': 15,
      },
      {
        'id': 2,
        'code': 'HCM-02',
        'name': 'Cafe Phú Nhuận',
        'managerName': 'Trần Hoàng Nam',
        'status': 'ACTIVE',
        'currentStaffCount': 8,
        'maxStaff': 12,
      },
      {
        'id': 3,
        'code': 'HCM-03',
        'name': 'Cafe Bình Thạnh',
        'managerName': null,
        'status': 'MAINTENANCE',
        'currentStaffCount': 0,
        'maxStaff': 15,
      },
    ];
    await preview(
      tester,
      AppShell(
        title: 'Quản trị hệ thống',
        subtitle: 'HRM Cafe · Admin',
        selectedIndex: 1,
        onDestinationSelected: (_) {},
        onLogout: () {},
        destinations: const [
          AppDestination('Tổng quan', Icons.dashboard_outlined),
          AppDestination('Chi nhánh', Icons.storefront_outlined),
          AppDestination('Tài khoản', Icons.people_outline),
          AppDestination('Chấm công', Icons.fact_check_outlined),
        ],
        child: AdminBranchesTab(
          stores: stores,
          onRefresh: () async {},
          onAddStore: () {},
          onEditStore: (_) {},
          onDeleteStore: (_, __) {},
        ),
      ),
      const Size(1440, 1000),
      'admin-desktop',
    );
    expect(find.byType(PaginatedDataTable), findsOneWidget);
  });
  testWidgets('report-phone', (tester) async {
    await preview(
      tester,
      managerShell(
        BranchReportsTab(
          report: {
            'staffCount': 12,
            'scheduled': 60,
            'attended': 55,
            'attendanceRate': 91.7,
            'daily': [
              for (int d = 19; d <= 23; d++)
                {
                  'date': '2026-10-$d',
                  'scheduled': 12,
                  'attended': d == 20 ? 10 : 11,
                },
            ],
          },
          staffCount: 12,
          reportFrom: DateTime(2026, 10, 19),
          reportTo: DateTime(2026, 10, 25),
          onSelectReportRange: () {},
        ),
        selected: 4,
      ),
      const Size(390, 844),
      'report-phone',
    );
  });
  testWidgets('account-form-small-large-text', (tester) async {
    await preview(
      tester,
      UserFormDialog(
        stores: const [],
        onSubmit: (_) async {},
        showSnackBar: (_, {bool isError = false}) {},
      ),
      const Size(320, 740),
      'account-form-small-large-text',
      scale: 1.5,
    );
  });
  testWidgets('account form actions remain above keyboard', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await preview(
      tester,
      UserFormDialog(
        stores: const [],
        onSubmit: (_) async {},
        showSnackBar: (_, {bool isError = false}) {},
      ),
      const Size(390, 844),
      'account-form-keyboard',
    );
    expect(
      tester
          .getBottomRight(find.widgetWithText(FilledButton, 'Tạo tài khoản'))
          .dy,
      lessThanOrEqualTo(544),
    );
  });
}
