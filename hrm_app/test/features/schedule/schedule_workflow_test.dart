import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/staff/presentation/cubit/staff_cubit.dart';
import 'package:hrm_app/features/admin/presentation/tabs/admin_schedule_tab.dart';
import 'package:hrm_app/features/staff/presentation/tabs/staff_schedule_tab.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/schedule_week_strip.dart';
import 'package:hrm_app/features/admin/presentation/dialogs/shift_transfer_dialog.dart';

import '../../support/fakes.dart';
import '../../presentation/visual_smoke_test.dart' show preview;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'HRMSans',
    )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final day = DateUtils.dateOnly(DateTime.now());
  final monday = day.subtract(Duration(days: day.weekday - 1));
  final shifts = [
    {
      'id': 1,
      'name': 'Ca sáng',
      'startTime': '08:00:00',
      'endTime': '16:00:00',
      'breakMinutes': 30,
      'active': true,
    },
    {
      'id': 2,
      'name': 'Ca cũ',
      'startTime': '07:00:00',
      'endTime': '12:00:00',
      'breakMinutes': 0,
      'active': false,
    },
  ];
  for (final config in [
    ('admin-schedule-phone', const Size(390, 844), 1.0),
    ('admin-schedule-small-large-text', const Size(320, 740), 1.5),
  ]) {
    testWidgets(config.$1, (tester) async {
      final queries = <Map<String, dynamic>>[];
      final dio = testDio((o) {
        if (o.uri.path.endsWith('/shifts')) return jsonResponse(shifts);
        if (o.uri.path.endsWith('/roster/settings')) return jsonResponse([]);
        queries.add(o.queryParameters);
        return jsonResponse([
          {
            'id': 1,
            'userName': 'Lan',
            'userId': 10,
            'storeId': 1,
            'shiftName': 'Ca sáng',
            'date': ScheduleWeekStrip.keyOf(day),
            'startTime': '08:00:00',
            'endTime': '16:00:00',
            'storeName': 'Cafe Thủ Đức',
            'published': true,
          },
        ]);
      });
      addTearDown(dio.close);
      await preview(
        tester,
        Scaffold(
          body: AdminScheduleTab(
            dio: dio,
            stores: const [
              {'id': 1, 'name': 'Cafe Thủ Đức'},
            ],
          ),
        ),
        config.$2,
        config.$1,
        scale: config.$3,
      );
      await tester.scrollUntilVisible(
        find.text('Lan'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Lan'), findsOneWidget);
      expect(queries.first['from'], ScheduleWeekStrip.keyOf(monday));
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mẫu ca'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Đã ngừng sử dụng'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đã ngừng sử dụng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('admin validates template and saves lifecycle settings', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    final dio = testDio((o) {
      if (o.method == 'PUT') {
        saved = Map<String, dynamic>.from(o.data as Map);
        return jsonResponse(shifts.first);
      }
      return jsonResponse(o.uri.path.endsWith('/shifts') ? shifts : []);
    });
    addTearDown(dio.close);
    await preview(
      tester,
      Scaffold(
        body: AdminScheduleTab(dio: dio, stores: const []),
      ),
      const Size(1000, 1000),
      'admin-schedule-desktop',
    );
    await tester.tap(find.text('Mẫu ca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sửa mẫu ca').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nghỉ giữa ca (phút)'),
      '480',
    );
    await tester.tap(find.text('Lưu mẫu ca'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.textContaining('thời gian nghỉ phải nhỏ hơn'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nghỉ giữa ca (phút)'),
      '45',
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Lưu mẫu ca'));
    await tester.pumpAndSettle();
    expect(saved?['breakMinutes'], 45);
    expect(saved?['active'], false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin switches day week month and filters branch queries', (
    tester,
  ) async {
    final queries = <Map<String, dynamic>>[];
    final dio = testDio((o) {
      if (o.uri.path.endsWith('/shifts')) return jsonResponse(shifts);
      if (o.uri.path.endsWith('/roster/settings')) return jsonResponse([]);
      queries.add(Map<String, dynamic>.from(o.queryParameters));
      return jsonResponse([]);
    });
    addTearDown(dio.close);
    await preview(
      tester,
      Scaffold(
        body: AdminScheduleTab(
          dio: dio,
          stores: const [
            {'id': 1, 'name': 'Cafe Thủ Đức'},
            {'id': 2, 'name': 'Cafe Quận 1'},
          ],
        ),
      ),
      const Size(1200, 1000),
      'admin-calendar-navigation',
    );
    expect(queries.last['from'], ScheduleWeekStrip.keyOf(monday));
    await tester.tap(find.text('Ngày'));
    await tester.pumpAndSettle();
    expect(queries.last['from'], ScheduleWeekStrip.keyOf(day));
    expect(queries.last['to'], ScheduleWeekStrip.keyOf(day));
    await tester.tap(find.byTooltip('Kỳ sau'));
    await tester.pumpAndSettle();
    expect(
      queries.last['from'],
      ScheduleWeekStrip.keyOf(day.add(const Duration(days: 1))),
    );
    await tester.tap(find.text('Hôm nay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tháng'));
    await tester.pumpAndSettle();
    expect(
      queries.last['from'],
      ScheduleWeekStrip.keyOf(DateTime(day.year, day.month, 1)),
    );
    expect(
      queries.last['to'],
      ScheduleWeekStrip.keyOf(DateTime(day.year, day.month + 1, 0)),
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cafe Quận 1').last);
    await tester.pumpAndSettle();
    expect(queries.last['storeId'], 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'admin transfers a shift, keeps choice on error and refreshes staffing',
    (tester) async {
      final future = day.add(const Duration(days: 7));
      final date = ScheduleWeekStrip.keyOf(future);
      var storeId = 1, attempts = 0;
      Map<String, dynamic>? saved;
      final dio = testDio((o) {
        if (o.uri.path.endsWith('/shifts')) return jsonResponse(shifts);
        if (o.uri.path.endsWith('/roster/settings')) {
          return jsonResponse([
            for (final id in [1, 2])
              {
                'storeId': id,
                'plans': [
                  {
                    'slot': 'MORNING',
                    'shiftId': 1,
                    'shiftName': 'Ca sáng',
                    'startTime': '08:00:00',
                    'endTime': '16:00:00',
                    'active': true,
                    'requiredStaff': 1,
                  },
                ],
              },
          ]);
        }
        if (o.method == 'PUT') {
          attempts++;
          saved = Map<String, dynamic>.from(o.data as Map);
          if (attempts == 1) {
            return jsonResponse(
              null,
              status: 400,
              success: false,
              message: 'Ca đã thay đổi. Hãy thử lại.',
            );
          }
          storeId = saved!['targetStoreId'] as int;
          return jsonResponse({});
        }
        return jsonResponse([
          {
            'id': 8,
            'userId': 10,
            'userName': 'Lan',
            'shiftId': 1,
            'shiftName': 'Ca sáng',
            'date': date,
            'slot': 'MORNING',
            'startTime': '08:00:00',
            'endTime': '16:00:00',
            'status': 'PENDING',
            'published': true,
            'storeId': storeId,
            'storeName': storeId == 1 ? 'Cafe Thủ Đức' : 'Cafe Quận 1',
            'temporaryTransfer': storeId == 2,
          },
        ]);
      });
      addTearDown(dio.close);
      await preview(
        tester,
        Scaffold(
          body: AdminScheduleTab(
            dio: dio,
            stores: const [
              {'id': 1, 'name': 'Cafe Thủ Đức'},
              {'id': 2, 'name': 'Cafe Quận 1'},
              {'id': 3, 'name': 'Chi nhánh đã đóng', 'status': 'CLOSED'},
            ],
          ),
        ),
        const Size(1400, 1400),
        'admin-roster-desktop',
      );
      await tester.tap(find.byTooltip('Kỳ sau'));
      await tester.pumpAndSettle();
      expect(find.text('Đủ nhân sự · 1/1 nhân viên'), findsOneWidget);
      expect(find.text('Thiếu 1 người · 0/1 nhân viên'), findsOneWidget);
      await tester.tap(find.byTooltip('Điều chuyển ca'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      expect(find.text('Chi nhánh đã đóng'), findsNothing);
      await tester.tap(find.text('Cafe Quận 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chuyển ca'));
      await tester.pumpAndSettle();
      expect(find.text('Ca đã thay đổi. Hãy thử lại.'), findsOneWidget);
      expect(saved, {'sourceStoreId': 1, 'targetStoreId': 2});
      await tester.tap(find.text('Chuyển ca'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(ShiftTransferDialog), findsNothing);
      expect(find.text('Hỗ trợ chi nhánh'), findsOneWidget);
      expect(find.text('Đủ nhân sự · 1/1 nhân viên'), findsOneWidget);
      expect(find.text('Thiếu 1 người · 0/1 nhân viên'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transfer form fits small screen with large text', (
    tester,
  ) async {
    await preview(
      tester,
      ShiftTransferDialog(
        schedule: {
          'userName': 'Nguyễn Thị Minh Anh',
          'shiftName': 'Ca sáng',
          'date': ScheduleWeekStrip.keyOf(day),
          'startTime': '08:00',
          'endTime': '12:00',
          'storeName': 'Cafe Thủ Đức',
          'published': false,
        },
        stores: const [
          {'id': 2, 'name': 'Cafe Quận 1'},
        ],
        onSave: (_) async {},
      ),
      const Size(320, 740),
      'admin-transfer-small-large-text',
      scale: 1.5,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff week selects a day and returns to all upcoming shifts', (
    tester,
  ) async {
    final dates = [monday, monday.add(const Duration(days: 1))];
    var requested = false;
    final state = StaffState(
      anchor: monday,
      data: {
        'schedules': [
          for (var i = 0; i < 2; i++)
            {
              'id': i + 1,
              'date': ScheduleWeekStrip.keyOf(dates[i]),
              'shiftName': 'Ca ${i + 1}',
              'startTime': '08:00:00',
              'endTime': '16:00:00',
              'status': 'PENDING',
              'storeName': 'Cafe Thủ Đức',
              'startsAt': '${ScheduleWeekStrip.keyOf(dates[i])}T08:00:00',
              'endsAt': '${ScheduleWeekStrip.keyOf(dates[i])}T16:00:00',
            },
        ],
      },
    );
    await preview(
      tester,
      Scaffold(
        body: StaffScheduleTab(
          state: state,
          refresh: () async {},
          change: ({anchor, month}) {},
          details: (_) {},
          swap: (_) {},
          request: () => requested = true,
        ),
      ),
      const Size(390, 1200),
      'staff-schedule-week-phone',
    );
    await tester.tap(find.text('T2'));
    await tester.pumpAndSettle();
    expect(find.text('Ca 1'), findsOneWidget);
    expect(find.text('Ca 2'), findsNothing);
    await tester.tap(find.text('Xem cả tuần · Ca sắp tới trước'));
    await tester.pumpAndSettle();
    expect(find.text('Ca 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gửi yêu cầu đổi ca / xin nghỉ'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Gửi yêu cầu đổi ca / xin nghỉ'));
    expect(requested, true);
    expect(tester.takeException(), isNull);
  });
}
