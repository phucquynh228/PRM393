import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/staff/presentation/cubit/staff_cubit.dart';
import 'package:hrm_app/features/admin/presentation/tabs/admin_schedule_tab.dart';
import 'package:hrm_app/features/staff/presentation/tabs/staff_schedule_tab.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/schedule_week_strip.dart';

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
        queries.add(o.queryParameters);
        return jsonResponse([
          {
            'id': 1,
            'userName': 'Lan',
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
      expect(find.text('Lan · Ca sáng'), findsOneWidget);
      expect(queries.first['from'], ScheduleWeekStrip.keyOf(monday));
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
