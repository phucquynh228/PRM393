import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/branch/presentation/tabs/branch_schedule_tab.dart';
import 'package:hrm_app/features/branch/presentation/dialogs/shift_roster_dialogs.dart';
import 'package:hrm_app/features/branch/presentation/dialogs/branch_staff_sheets.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/fixed_roster_editor.dart';

import '../../presentation/visual_smoke_test.dart' show preview;

final day = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7));
String get ymd =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
const people = [
  {'id': 1, 'name': 'Nguyễn Minh Anh', 'phone': '0901000001'},
  {'id': 2, 'name': 'Trần Hoàng Nam', 'phone': '0901000002'},
  {'id': 3, 'name': 'Phạm Thảo Nguyên', 'phone': '0901000003'},
];
final templates = [
  {
    'id': 1,
    'name': 'Ca sáng',
    'startTime': '07:00:00',
    'endTime': '12:00:00',
    'active': true,
  },
  {
    'id': 2,
    'name': 'Ca chiều',
    'startTime': '12:00:00',
    'endTime': '17:00:00',
    'active': true,
  },
  {
    'id': 3,
    'name': 'Ca tối',
    'startTime': '17:00:00',
    'endTime': '22:00:00',
    'active': true,
  },
];
final plans = [
  for (int i = 0; i < 3; i++)
    {
      ...templates[i],
      'slot': rosterSlots.keys.elementAt(i),
      'shiftId': i + 1,
      'shiftName': templates[i]['name'],
      'requiredStaff': i == 2 ? 4 : 2,
    },
];
final assignments = [
  {
    'id': 10,
    'userId': 1,
    'userName': 'Nguyễn Minh Anh',
    'date': ymd,
    'slot': 'MORNING',
    'shiftId': 1,
    'shiftName': 'Ca sáng',
    'startTime': '07:00:00',
    'endTime': '12:00:00',
    'status': 'PENDING',
    'published': false,
  },
  {
    'id': 11,
    'userId': 3,
    'userName': 'Phạm Thảo Nguyên',
    'date': ymd,
    'slot': 'EVENING',
    'shiftId': 3,
    'shiftName': 'Ca tối',
    'startTime': '17:00:00',
    'endTime': '22:00:00',
    'status': 'ON_LEAVE',
    'published': true,
  },
];
Future<void> pickDate({
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
  required ValueChanged<DateTime> onPicked,
}) async {}
typedef Send = Future<void> Function(
  String method,
  String path, {
  Object? data,
});
Widget schedule({
  Send? send,
  Future<Map<String, dynamic>> Function(DateTime)? generate,
}) => Scaffold(
  body: BranchScheduleTab(
    schedules: assignments,
    staff: people,
    shifts: templates,
    plans: plans,
    schedulePeriod: 'Week',
    selectedDate: day,
    scheduleFrom: day.subtract(Duration(days: day.weekday - 1)),
    scheduleTo: day.add(Duration(days: 7 - day.weekday)),
    onDateChanged: (_) {},
    onPeriodChanged: (_) {},
    onSend: send ?? (_, _, {Object? data}) async {},
    onReloadSchedules: () async {},
    showMessage: (_, {bool isError = false}) {},
    cleanError: (error) => error.toString().replaceFirst('Exception: ', ''),
    onPickDate: pickDate,
    onGenerateWeek: generate,
  ),
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
    ('shift-centric-phone', const Size(390, 844), 1.0),
    ('shift-centric-small-text', const Size(320, 740), 1.5),
    ('shift-centric-desktop', const Size(1200, 1000), 1.0),
  ]) {
    testWidgets(config.$1, (tester) async {
      await preview(tester, schedule(), config.$2, config.$1, scale: config.$3);
      await tester.scrollUntilVisible(
        find.text('Thiếu 4 người · 0/4 nhân viên'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ca Sáng'), findsOneWidget);
      expect(find.text('Ca Chiều'), findsOneWidget);
      expect(find.text('Ca Tối'), findsOneWidget);
      expect(find.text('Thiếu 1 người · 1/2 nhân viên'), findsOneWidget);
      expect(find.text('Thiếu 2 người · 0/2 nhân viên'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'multi-select adds only new staff, keeps selection on failure, and sends one batch',
    (tester) async {
      var calls = 0;
      Map<String, dynamic>? body;
      await preview(
        tester,
        schedule(
          send: (method, path, {Object? data}) async {
            expect(method, 'POST');
            expect(path, '/manager/schedules/batch');
            body = Map<String, dynamic>.from(data as Map);
            calls++;
            if (calls == 1) throw Exception('Nhân viên có lịch trùng');
          },
        ),
        const Size(1200, 1000),
        'shift-centric-picker-launch',
      );
      await tester.tap(find.text('Thêm nhân sự').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Nguyễn Minh Anh'),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Trần Hoàng Nam'));
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'Phạm Thảo Nguyên'),
      );
      await tester.pump();
      await tester.tap(find.text('Thêm 2 nhân sự'));
      await tester.pumpAndSettle();
      expect(find.text('Nhân viên có lịch trùng'), findsOneWidget);
      expect(body, {
        'date': ymd,
        'slot': 'MORNING',
        'userIds': [2, 3],
      });
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Trần Hoàng Nam'),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.text('Thêm 2 nhân sự'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(ShiftStaffPicker), findsNothing);
    },
  );

  testWidgets(
    'staff profile persists weekday and default slot with the rest of the profile',
    (tester) async {
      Map<String, dynamic>? saved;
      await preview(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => BranchStaffFormSheet.show(
                context,
                staff: people[0],
                onSend: (_, _, {Object? data}) async =>
                    saved = Map<String, dynamic>.from(data as Map),
                onReload: () async {},
                showMessage: (_, {bool isError = false}) {},
                cleanError: (e) => '$e',
              ),
              child: const Text('Mở hồ sơ'),
            ),
          ),
        ),
        const Size(390, 844),
        'fixed-roster-profile-launch',
      );
      await tester.tap(find.text('Mở hồ sơ'));
      await tester.pumpAndSettle();
      final checkbox = find.byType(Checkbox).at(2);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      await tester.tap(find.text('Lưu nhân viên'));
      await tester.pumpAndSettle();
      expect(saved?['fixedRoster'], [
        {'dayOfWeek': 1, 'slot': 'EVENING'},
      ]);
    },
  );

  testWidgets(
    'staffing settings validate numbers and preserve branch slot mapping',
    (tester) async {
      List<Map<String, dynamic>>? saved;
      await preview(
        tester,
        ShiftStaffingSettingsDialog(
          plans: plans,
          shifts: templates,
          cleanError: (e) => '$e',
          onSave: (slots) async => saved = slots,
        ),
        const Size(390, 844),
        'shift-staffing-settings',
      );
      final field = find.byType(TextFormField).first;
      await tester.enterText(field, '-1');
      await tester.tap(find.text('Lưu định mức'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Nhập số nguyên từ 0 đến 200'), findsOneWidget);
      await tester.enterText(field, '3');
      await tester.tap(find.text('Lưu định mức'));
      await tester.pumpAndSettle();
      expect(saved!.first, {
        'slot': 'MORNING',
        'shiftId': 1,
        'requiredStaff': 3,
      });
      expect(saved!.last['requiredStaff'], 4);
    },
  );

  testWidgets(
    'generation reports skipped leave and publication counts pending drafts only',
    (tester) async {
      DateTime? requested;
      await preview(
        tester,
        schedule(
          generate: (monday) async {
            requested = monday;
            return {
              'created': 2,
              'existing': 1,
              'skipped': [
                {
                  'userName': 'Phạm Thảo Nguyên',
                  'date': ymd,
                  'slot': 'EVENING',
                  'reason': 'Đã được duyệt nghỉ',
                },
              ],
            };
          },
        ),
        const Size(1200, 1000),
        'shift-generate-launch',
      );
      expect(find.text('Công bố 1 ca nháp'), findsOneWidget);
      await tester.tap(find.text('Tạo nháp tuần mới'));
      await tester.pumpAndSettle();
      expect(requested!.weekday, DateTime.monday);
      expect(find.text('2 ca mới · 1 ca đã có · 1 ca bỏ qua'), findsOneWidget);
      expect(find.textContaining('Đã được duyệt nghỉ'), findsOneWidget);
    },
  );
}
