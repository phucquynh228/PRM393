import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/admin/data/attendance_report_exporter.dart';
import 'package:hrm_app/features/admin/presentation/screens/attendance_report_screen.dart';

import '../../support/fakes.dart';
import '../../presentation/visual_smoke_test.dart' show preview;

const users = [
  {'id': 2, 'name': 'Nguyễn Thị Thảo Nguyên'},
];
const stores = [
  {'id': 3, 'name': 'Cafe Thủ Đức'},
];
Map<String, dynamic> summaryJson({bool empty = false}) => {
  'employeeCount': empty ? 0 : 3,
  'completedShifts': empty ? 0 : 60,
  'lateShifts': empty ? 0 : 4,
  'unexcusedAbsences': empty ? 0 : 1,
  'employees': empty
      ? []
      : [
          {
            'employeeCode': 'NV-0002',
            'userName': 'Nguyễn Thị Thảo Nguyên',
            'completedShifts': 22,
            'lateShifts': 1,
            'unexcusedAbsences': 0,
          },
          {
            'employeeCode': 'NV-0003',
            'userName': 'Trần B',
            'completedShifts': 20,
            'lateShifts': 0,
            'unexcusedAbsences': 0,
          },
          {
            'employeeCode': 'NV-0004',
            'userName': 'Lê C',
            'completedShifts': 18,
            'lateShifts': 3,
            'unexcusedAbsences': 1,
          },
        ],
};
AttendanceReportSummary summary({bool empty = false}) =>
    AttendanceReportSummary.fromJson(summaryJson(empty: empty));

void main() {
  setUpAll(() async {
    await (FontLoader(
      'HRMSans',
    )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'calendar periods include leap years and normalize query and filename',
    () {
      final month = AttendanceReportRequest(
        period: AttendanceReportPeriod.month,
        date: DateTime(2024, 2, 29),
        userId: 2,
        storeId: 3,
      );
      expect(month.query, {
        'period': 'month',
        'date': '2024-02-01',
        'userId': 2,
        'storeId': 3,
      });
      expect(month.to, DateTime(2024, 2, 29));
      expect(
        month.filename,
        'bao-cao-cham-cong_2024-02-01_2024-02-29_nv-2_cn-3',
      );
      expect(month.label, 'Tháng 2/2024');
      final year = AttendanceReportRequest(
        period: AttendanceReportPeriod.year,
        date: month.date,
      );
      expect(year.from, DateTime(2024));
      expect(year.to, DateTime(2024, 12, 31));
    },
  );

  for (final format in AttendanceReportFormat.values) {
    test(
      'downloads authenticated ${format.extension} with the selected format',
      () async {
        final bytes = format == AttendanceReportFormat.pdf
            ? utf8.encode('%PDF-1.7')
            : [80, 75, 3, 4];
        final dio = testDio((options) {
          expect(options.path, endsWith('/admin/attendance/export'));
          expect(options.queryParameters, {
            'period': 'month',
            'date': '2024-02-01',
            'format': format.extension,
          });
          expect(options.headers['Authorization'], 'Bearer test-token');
          return ResponseBody.fromBytes(bytes, 200);
        });
        dio.options.headers['Authorization'] = 'Bearer test-token';
        addTearDown(dio.close);
        final exporter = AttendanceReportExporter(
          dio,
          save: (name, data, actualFormat) async {
            expect(name, 'bao-cao-cham-cong_2024-02-01_2024-02-29');
            expect(data, bytes);
            expect(actualFormat, format);
            return '$name.${format.extension}';
          },
        );
        expect(
          await exporter.export(
            AttendanceReportRequest(
              period: AttendanceReportPeriod.month,
              date: DateTime(2024, 2, 29),
            ),
            format: format,
          ),
          isTrue,
        );
      },
    );
  }

  test('loads server summary with the selected scope', () async {
    final dio = testDio((options) {
      expect(options.path, endsWith('/attendance/report'));
      expect(options.queryParameters['storeId'], 3);
      return jsonResponse(summaryJson());
    });
    addTearDown(dio.close);
    final report = await AttendanceReportExporter(dio).loadSummary(
      AttendanceReportRequest(
        period: AttendanceReportPeriod.month,
        date: DateTime(2026, 10),
        storeId: 3,
      ),
    );
    expect(report.completedShifts, 60);
    expect(report.employees.first.userName, 'Nguyễn Thị Thảo Nguyên');
  });

  test(
    'server errors are readable and never saved; cancellation is not success',
    () async {
      final request = AttendanceReportRequest(
        period: AttendanceReportPeriod.month,
        date: DateTime(2026, 10),
      );
      final dio = testDio(
        (_) => ResponseBody.fromString(
          jsonEncode({'message': 'Không có dữ liệu'}),
          400,
        ),
      );
      addTearDown(dio.close);
      await expectLater(
        AttendanceReportExporter(
          dio,
          save: (_, _, _) async => fail('Must not save'),
        ).export(request),
        throwsA(
          predicate((error) => error.toString().contains('Không có dữ liệu')),
        ),
      );
      final success = testDio((_) => ResponseBody.fromBytes([1], 200));
      addTearDown(success.close);
      expect(
        await AttendanceReportExporter(
          success,
          save: (_, _, _) async => null,
        ).export(request),
        isFalse,
      );
    },
  );

  for (final config in [
    ('attendance-report-phone', const Size(390, 844), 1.0),
    ('attendance-report-small-large-text', const Size(320, 740), 1.5),
    ('attendance-report-desktop', const Size(1100, 1100), 1.0),
  ]) {
    testWidgets(config.$1, (tester) async {
      await preview(
        tester,
        AttendanceReportScreen(
          users: users,
          stores: stores,
          onLoad: (_) async => summary(),
          onExport: (_, _) async => false,
        ),
        config.$2,
        config.$1,
        scale: config.$3,
      );
      expect(find.text('KHOẢNG THỜI GIAN'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Xuất Excel'), 200);
      expect(find.text('Xuất PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('period change reloads data and export uses the same scope', (
    tester,
  ) async {
    final gate = Completer<bool>();
    AttendanceReportRequest? exported;
    AttendanceReportFormat? format;
    final loaded = <AttendanceReportRequest>[];
    await preview(
      tester,
      AttendanceReportScreen(
        users: users,
        stores: stores,
        onLoad: (request) async {
          loaded.add(request);
          return summary();
        },
        onExport: (request, selectedFormat) {
          exported = request;
          format = selectedFormat;
          return gate.future;
        },
      ),
      const Size(1100, 1100),
      'attendance-report-interaction',
    );
    expect(loaded.single.period, AttendanceReportPeriod.month);
    await tester.tap(find.byKey(const ValueKey('report-period-selector')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<AttendanceReportPeriod>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theo năm').last);
    await tester.pumpAndSettle();
    expect(loaded.last.period, AttendanceReportPeriod.year);
    await tester.scrollUntilVisible(find.text('Xuất PDF'), 200);
    await tester.tap(find.text('Xuất PDF'));
    await tester.pump();
    expect(format, AttendanceReportFormat.pdf);
    expect(exported!.query, loaded.last.query);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xuất Excel'))
          .onPressed,
      isNull,
    );
    gate.completeError(Exception('Không lưu được PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Không lưu được PDF'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xuất Excel'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('empty report displays zero and disables file export', (
    tester,
  ) async {
    await preview(
      tester,
      AttendanceReportScreen(
        users: users,
        stores: stores,
        onLoad: (_) async => summary(empty: true),
        onExport: (_, _) async => fail('No export for empty report'),
      ),
      const Size(1100, 1100),
      'attendance-report-empty',
    );
    expect(find.text('0'), findsNWidgets(4));
    await tester.scrollUntilVisible(find.text('Xuất Excel'), 200);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xuất Excel'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('stale requests cannot overwrite a newer period', (tester) async {
    final older = Completer<AttendanceReportSummary>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceReportScreen(
          users: users,
          stores: stores,
          onLoad: (_) {
            calls++;
            return calls == 1 ? older.future : Future.value(summary());
          },
          onExport: (_, _) async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('report-period-selector')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(
      find.byType(DropdownButtonFormField<AttendanceReportPeriod>),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Theo năm').last);
    await tester.pumpAndSettle();
    expect(find.text('60'), findsOneWidget);
    older.complete(summary(empty: true));
    await tester.pumpAndSettle();
    expect(find.text('60'), findsOneWidget);
  });
}
