import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/admin/presentation/dialogs/branch_closure_dialog.dart';
import 'package:hrm_app/features/admin/presentation/tabs/admin_branches_tab.dart';
import 'package:hrm_app/features/branch/presentation/dialogs/branch_schedule_sheet.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';

import '../../support/fakes.dart';
import '../../presentation/visual_smoke_test.dart' show preview;

const source = {
  'id': 1,
  'name': 'Cafe Thủ Đức',
  'status': 'ACTIVE',
  'canDelete': false,
};
const target = {
  'id': 2,
  'name': 'Cafe Quận 1',
  'status': 'ACTIVE',
  'currentStaffCount': 3,
  'maxStaff': 15,
};
const employee = {
  'id': 3,
  'name': 'Nguyễn Thị Thảo Nguyên',
  'phone': '0902000101',
  'role': 'STAFF',
  'storeId': 1,
};
Map<String, dynamic> closurePreview({int open = 0}) => {
  'id': 1,
  'name': 'Cafe Thủ Đức',
  'status': 'ACTIVE',
  'employees': [employee],
  'futureSchedules': 3,
  'pendingRequests': 1,
  'openAttendances': open,
  'adminAccounts': 1,
};

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
    ('branch-close-phone', const Size(390, 844), 1.0),
    ('branch-close-small-large-text', const Size(320, 740), 1.5),
    ('branch-close-desktop', const Size(1100, 1000), 1.0),
  ]) {
    testWidgets(config.$1, (tester) async {
      final dio = testDio((o) => jsonResponse(closurePreview()));
      addTearDown(dio.close);
      await preview(
        tester,
        BranchClosureDialog(
          dio: dio,
          stores: const [source, target],
          store: source,
        ),
        config.$2,
        config.$1,
        scale: config.$3,
      );
      expect(find.text('Ngừng hoạt động chi nhánh'), findsOneWidget);
      expect(find.textContaining('3 ca sắp tới'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'closing requires reason and an explicit decision for every employee',
    (tester) async {
      Map<String, dynamic>? submitted;
      final dio = testDio((o) {
        if (o.method == 'POST') {
          submitted = Map<String, dynamic>.from(o.data as Map);
          return jsonResponse({});
        }
        return jsonResponse(closurePreview());
      });
      addTearDown(dio.close);
      await preview(
        tester,
        BranchClosureDialog(
          dio: dio,
          stores: const [source, target],
          store: source,
        ),
        const Size(1000, 1400),
        'branch-close-validation',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận ngừng hoạt động'));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      expect(find.text('Nhập lý do ngừng hoạt động'), findsOneWidget);
      expect(find.text('Chọn cách xử lý nhân viên'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Lý do ngừng hoạt động'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lý do ngừng hoạt động'),
        'Kết thúc thuê mặt bằng',
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chờ điều chuyển').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận ngừng hoạt động'));
      await tester.pumpAndSettle();
      expect(submitted?['reason'], 'Kết thúc thuê mặt bằng');
      expect((submitted?['placements'] as List).single, {
        'userId': 3,
        'action': 'WAITING_TRANSFER',
        'manager': false,
      });
    },
  );

  testWidgets('open attendance blocks closure', (tester) async {
    var submitted = false;
    final dio = testDio((o) {
      if (o.method == 'POST') submitted = true;
      return jsonResponse(closurePreview(open: 1));
    });
    addTearDown(dio.close);
    await preview(
      tester,
      BranchClosureDialog(
        dio: dio,
        stores: const [source, target],
        store: source,
      ),
      const Size(1000, 1000),
      'branch-close-blocked',
    );
    expect(find.textContaining('còn nhân viên chưa check-out'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận ngừng hoạt động'),
          )
          .onPressed,
      isNull,
    );
    expect(submitted, false);
  });

  testWidgets(
    'placement excludes closed and current branches and keeps choices on failure',
    (tester) async {
      Map<String, dynamic>? submitted;
      final dio = testDio((o) {
        submitted = Map<String, dynamic>.from(o.data as Map);
        return jsonResponse(
          null,
          status: 400,
          success: false,
          message: 'Chi nhánh nhận đã hết chỗ',
        );
      });
      addTearDown(dio.close);
      await preview(
        tester,
        BranchClosureDialog(
          dio: dio,
          stores: const [
            source,
            target,
            {'id': 9, 'name': 'Chi nhánh đóng', 'status': 'CLOSED'},
          ],
          employee: employee,
        ),
        const Size(1000, 1200),
        'staff-placement',
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Điều chuyển chi nhánh').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chi nhánh đóng'), findsNothing);
      expect(find.textContaining('Cafe Thủ Đức'), findsNothing);
      await tester.tap(find.textContaining('Cafe Quận 1').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu bố trí'));
      await tester.pumpAndSettle();
      expect(submitted, {
        'userId': 3,
        'action': 'TRANSFER',
        'targetStoreId': 2,
        'manager': false,
      });
      expect(find.text('Chi nhánh nhận đã hết chỗ'), findsOneWidget);
      expect(find.textContaining('Cafe Quận 1'), findsOneWidget);
      expect(find.text('Điều chuyển chi nhánh'), findsOneWidget);
    },
  );

  testWidgets(
    'branches with history offer closure and hide permanent deletion',
    (tester) async {
      final dio = testDio((o) => jsonResponse(null));
      addTearDown(dio.close);
      await preview(
        tester,
        Scaffold(
          body: AdminBranchesTab(
            stores: const [source],
            onRefresh: () async {},
            onAddStore: () {},
            onEditStore: (_) {},
            onDeleteStore: (_, __) {},
            onCloseStore: (_) {},
          ),
        ),
        const Size(390, 844),
        'branch-list-close-action',
      );
      await tester.tap(find.byTooltip('Thao tác chi nhánh'));
      await tester.pumpAndSettle();
      expect(find.text('Ngừng hoạt động và xử lý nhân sự'), findsOneWidget);
      expect(find.text('Xóa vĩnh viễn chi nhánh trống'), findsNothing);
    },
  );

  testWidgets('a cancelled old assignment does not block the new shift form', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    final date = DateUtils.dateOnly(DateTime.now())
        .add(const Duration(days: 2));
    await preview(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => BranchScheduleSheet.show(
              context,
              staff: const [employee],
              shifts: const [
                {
                  'id': 1,
                  'name': 'Ca sáng',
                  'startTime': '08:00',
                  'endTime': '16:00',
                },
              ],
              schedules: [
                {
                  'id': 7,
                  'userId': 3,
                  'shiftId': 1,
                  'date': BranchHelpers.dateToYmd(date),
                  'startTime': '08:00',
                  'endTime': '16:00',
                  'status': 'CANCELLED',
                },
              ],
              initialDate: date,
              onSend: (_, __, {Object? data}) async {
                submitted = Map<String, dynamic>.from(data as Map);
              },
              onReload: () async {},
              showMessage: (_, {bool isError = false}) {},
              cleanError: (e) => '$e',
              onPickDate: ({
                required DateTime initial,
                DateTime? firstDate,
                DateTime? lastDate,
                required ValueChanged<DateTime> onPicked,
              }) async {},
            ),
            child: const Text('Phân ca mới'),
          ),
        ),
      ),
      const Size(1000, 1000),
      'new-shift-after-transfer',
    );
    await tester.tap(find.text('Phân ca mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu và công bố'));
    await tester.pumpAndSettle();
    expect(submitted?['userId'], 3);
    expect(submitted?['shiftId'], 1);
    expect(submitted?['date'], BranchHelpers.dateToYmd(date));
    expect(tester.takeException(), isNull);
  });
}
