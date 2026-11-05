import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/staff/data/repositories/staff_repository.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/staff/presentation/cubit/staff_cubit.dart';
import 'package:hrm_app/features/staff/presentation/screens/staff_screen.dart';
import 'package:hrm_app/features/staff/presentation/dialogs/staff_request_form.dart';
import 'package:hrm_app/features/staff/presentation/dialogs/staff_profile_form.dart';
import 'package:hrm_app/features/staff/presentation/widgets/staff_shift_card.dart';
import 'package:hrm_app/core/theme/app_theme.dart';

import '../../support/fakes.dart';
import '../../presentation/visual_smoke_test.dart' show preview;

StaffItem staffFixture() {
  final today = DateUtils.dateOnly(DateTime.now());
  final date = StaffRepository.date(today);
  final shift = <String, dynamic>{
    'id': 7,
    'scheduleId': 7,
    'date': date,
    'shiftName': 'Ca sáng',
    'startTime': '07:00:00',
    'endTime': '12:00:00',
    'startsAt': '${date}T07:00:00',
    'endsAt': '${date}T12:00:00',
    'status': 'CHECKED_IN',
    'storeName': 'Cafe Thủ Đức',
    'storeCode': 'HCM-TD01',
  };
  return {
    'profile': {
      'id': 3,
      'employeeCode': 'NV-0003',
      'name': 'Nguyễn Thị Thảo Nguyên',
      'phone': '0901000003',
      'role': 'STAFF',
      'storeName': 'Cafe Thủ Đức',
      'storeCode': 'HCM-TD01',
    },
    'today': [shift],
    'schedules': [shift],
    'weekWorkedMinutes': 1225,
    'weekPlannedMinutes': 1800,
    'attendance': [
      {
        'id': 42,
        'scheduleId': 7,
        'date': date,
        'shiftName': 'Ca sáng',
        'storeName': 'Cafe Thủ Đức',
        'status': 'CHECKED_IN',
        'checkInTime': '${date}T07:10:00',
        'checkOutTime': null,
        'workedMinutes': 0,
        'lateMinutes': 10,
        'earlyLeaveMinutes': 0,
      },
    ],
    'requests': [
      {
        'id': 11,
        'type': 'LEAVE',
        'status': 'PENDING',
        'startDate': date,
        'endDate': date,
        'reason': 'Có việc gia đình',
        'createdAt': '${date}T06:00:00',
        'canCancel': true,
      },
    ],
    'notifications': [
      {
        'id': 20,
        'title': 'Lịch làm đã được công bố',
        'message': 'Ca sáng tại Cafe Thủ Đức',
        'kind': 'SCHEDULE',
        'createdAt': '${date}T06:00:00',
        'read': false,
      },
    ],
  };
}

Widget staffApp(Dio dio, FakeAttendanceRepository attendance) =>
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<Dio>.value(value: dio),
        RepositoryProvider<AttendanceRepository>.value(value: attendance),
      ],
      child: const StaffScreen(name: 'Thảo Nguyên'),
    );

Future<void> nav(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> captureStaff(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'expired shift disables checkout and offers attendance correction',
    (tester) async {
      int checkedOut = 0, corrections = 0;
      final fixture = staffFixture();
      final shift = Map<String, dynamic>.from(
        (fixture['today'] as List).first as Map,
      );
      final record =
          Map<String, dynamic>.from(
              (fixture['attendance'] as List).first as Map,
            )
            ..['checkInTime'] = DateTime.now()
                .subtract(const Duration(days: 12))
                .toIso8601String();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StaffShiftCard(
                schedule: shift,
                record: record,
                attendanceActions: true,
                onCheckOut: () => checkedOut++,
                onCorrection: () => corrections++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Quá hạn check-out'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Cần sửa công'), findsOneWidget);
      await tester.ensureVisible(find.text('Yêu cầu sửa công'));
      await tester.tap(find.text('Yêu cầu sửa công'));
      expect(corrections, 1);
      expect(checkedOut, 0);
      expect(tester.takeException(), isNull);
    },
  );
  setUpAll(() async {
    await (FontLoader(
      'HRMSans',
    )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test(
    'latest schedule period wins when older request finishes later',
    () async {
      final first = Completer<ResponseBody>(),
          second = Completer<ResponseBody>();
      var count = 0;
      final dio = testDio((_) => ++count == 1 ? first.future : second.future);
      final cubit = StaffCubit(
        StaffRepository(dio),
        FakeAttendanceRepository(),
      );
      addTearDown(dio.close);
      addTearDown(cubit.close);
      final oldLoad = cubit.load(anchor: DateTime(2026, 10, 5));
      await Future<void>.delayed(Duration.zero);
      final newLoad = cubit.load(anchor: DateTime(2026, 11, 2));
      await Future<void>.delayed(Duration.zero);
      second.complete(jsonResponse({...staffFixture(), 'marker': 'new'}));
      await newLoad;
      first.complete(jsonResponse({...staffFixture(), 'marker': 'old'}));
      await oldLoad;
      expect(cubit.state.data['marker'], 'new');
      expect(cubit.state.from, DateTime(2026, 11, 2));
    },
  );

  test('checkout uses attendance id and failure keeps data without success message', () async {
    final dio = testDio((_) => jsonResponse(staffFixture()));
    final attendance = FakeAttendanceRepository()..failCheckout = true;
    final cubit = StaffCubit(StaffRepository(dio), attendance);
    addTearDown(dio.close);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.checkOut(42);
    expect(attendance.checkoutCalls, [42]);
    expect(cubit.state.message, isNull);
    expect(cubit.state.error, contains('Máy chủ từ chối'));
    expect(cubit.state.items('today'), isNotEmpty);
  });

  test('checkout prevents duplicate sends while action is pending', () async {
    final dio = testDio((_) => jsonResponse(staffFixture()));
    final gate = Completer<void>();
    final attendance = FakeAttendanceRepository()..checkoutGate = gate;
    final cubit = StaffCubit(StaffRepository(dio), attendance);
    addTearDown(dio.close);
    addTearDown(cubit.close);
    await cubit.load();
    final action = cubit.checkOut(42);
    await cubit.checkOut(42);
    expect(attendance.checkoutCalls, [42]);
    gate.complete();
    await action;
    expect(cubit.state.message, contains('check-out'));
    expect(cubit.state.busy, isFalse);
  });

  testWidgets(
    'staff can reach all six features on a phone and mark notification read',
    (tester) async {
      final paths = <String>[];
      final dio = testDio((o) {
        paths.add(o.path);
        return jsonResponse(
          o.path == '/staff/workspace' ? staffFixture() : null,
        );
      });
      addTearDown(dio.close);
      await preview(
        tester,
        staffApp(dio, FakeAttendanceRepository()),
        const Size(390, 844),
        'staff-dashboard-phone',
      );
      expect(find.text('Ca làm hôm nay'), findsOneWidget);
      await nav(tester, 'Chấm công');
      await captureStaff(tester, 'staff-attendance-phone');
      expect(find.text('Quên / sửa chấm công'), findsOneWidget);
      await nav(tester, 'Lịch làm');
      expect(find.text('Lịch làm việc'), findsOneWidget);
      expect(find.text('Tháng'), findsNothing);
      await tester.tap(find.byTooltip('Khoảng tiếp theo'));
      await tester.pumpAndSettle();
      expect(paths.where((p) => p == '/staff/workspace').length, 2);
      await captureStaff(tester, 'staff-schedule-phone');
      await nav(tester, 'Yêu cầu');
      expect(find.text('Có việc gia đình'), findsOneWidget);
      await captureStaff(tester, 'staff-requests-phone');
      await nav(tester, 'Thêm');
      await tester.tap(find.text('Thông báo').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đọc tất cả'));
      await tester.pumpAndSettle();
      expect(paths, contains('/staff/notifications/read-all'));
      await captureStaff(tester, 'staff-notifications-phone');
      await nav(tester, 'Thêm');
      await tester.tap(find.text('Hồ sơ').last);
      await tester.pumpAndSettle();
      expect(find.text('Thông tin cá nhân'), findsOneWidget);
      expect(find.text('Tài khoản và bảo mật'), findsOneWidget);
      expect(find.text('Quản lý tài khoản'), findsNothing);
      await captureStaff(tester, 'staff-profile-phone');
      await tester.tap(find.text('Thông tin công việc'));
      await tester.pumpAndSettle();
      expect(find.text('NV-0003'), findsOneWidget);
      expect(find.text('HCM-TD01'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tài khoản và bảo mật'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Đổi mật khẩu'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
      await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
      await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Đổi mật khẩu'),
        ),
      );
      await tester.pumpAndSettle();
      expect(paths, contains('/staff/password'));
      expect(paths.any((p) => p.contains('password-support')), isFalse);
      await tester.ensureVisible(find.text('Yêu cầu Admin hỗ trợ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yêu cầu Admin hỗ trợ'));
      await tester.pumpAndSettle();
      expect(find.text('Quên mật khẩu'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '0901000003',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final config in [
    ('staff-dashboard-desktop', const Size(1440, 1000), 1.0),
    ('staff-dashboard-small-large-text', const Size(320, 740), 1.6),
  ]) {
    testWidgets(config.$1, (tester) async {
      final dio = testDio((_) => jsonResponse(staffFixture()));
      addTearDown(dio.close);
      await preview(
        tester,
        staffApp(dio, FakeAttendanceRepository()),
        config.$2,
        config.$1,
        scale: config.$3,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('request form preserves input on server failure', (tester) async {
    final dio = testDio(
      (o) => o.method == 'GET'
          ? jsonResponse({'mine': [], 'peers': []})
          : jsonResponse(
              null,
              success: false,
              message: 'Chi nhánh chưa sẵn sàng',
            ),
    );
    addTearDown(dio.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: StaffRequestForm(repository: StaffRepository(dio)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Có việc gia đình');
    await tester.tap(find.text('Gửi tới quản lý'));
    await tester.pumpAndSettle();
    expect(find.text('Chi nhánh chưa sẵn sàng'), findsOneWidget);
    expect(find.text('Có việc gia đình'), findsOneWidget);
  });

  testWidgets('password form validates confirmation before calling API', (
    tester,
  ) async {
    var sends = 0;
    final dio = testDio((_) {
      sends++;
      return jsonResponse(null);
    });
    addTearDown(dio.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: StaffProfileForm(
          repository: StaffRepository(dio),
          profile: const {},
          password: true,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), '123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpassword');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu nhập lại chưa khớp'), findsOneWidget);
    expect(sends, 0);
  });
}
