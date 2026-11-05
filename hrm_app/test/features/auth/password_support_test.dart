import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/auth/data/repositories/password_support_repository.dart';
import 'package:hrm_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:hrm_app/features/admin/presentation/dialogs/password_support_decision_dialog.dart';
import 'package:hrm_app/features/admin/presentation/screens/password_support_screen.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets(
    'forgot password preserves input on failure and sends only a support report',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final dio = testDio((options) {
        expect(options.path, endsWith('/auth/password-support'));
        expect(options.method, 'POST');
        expect(options.data, {
          'phone': '0901000003',
          'name': 'Nhân viên',
          'note': 'Chi nhánh A',
        });
        calls++;
        return calls == 1
            ? jsonResponse(
                null,
                status: 503,
                success: false,
                message: 'Máy chủ đang bận',
              )
            : jsonResponse(
                null,
                status: 202,
                message:
                    'Vui lòng gặp trực tiếp Admin để xác minh và nhận hỗ trợ.',
              );
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ForgotPasswordScreen(dio: dio, initialPhone: '0901000003'),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Nhân viên');
      await tester.enterText(find.byType(TextFormField).at(2), 'Chi nhánh A');
      final send = find.widgetWithText(FilledButton, 'Gửi yêu cầu hỗ trợ');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('Máy chủ đang bận'), findsOneWidget);
      expect(find.text('Nhân viên'), findsOneWidget);
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('Đã tiếp nhận thông tin'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin must confirm matching passwords and identity before sending reset',
    (tester) async {
      var calls = 0;
      final repository = PasswordSupportRepository(
        testDio((options) {
          calls++;
          expect(options.path, endsWith('/admin/password-support/5'));
          expect(options.data['identityVerified'], isTrue);
          expect(options.data['newPassword'], 'new-password');
          return jsonResponse(
            null,
            status: 503,
            success: false,
            message: 'Chưa lưu được, hãy thử lại',
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PasswordSupportDecisionDialog(
                    repository: repository,
                    request: const {
                      'id': 5,
                      'name': 'Nhân viên',
                      'phone': '0901000003',
                    },
                    resolve: true,
                  ),
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'new-password');
      await tester.enterText(find.byType(TextFormField).at(1), 'different');
      await tester.tap(find.text('Xác nhận đặt lại'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Mật khẩu xác nhận chưa khớp'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
      await tester.tap(find.text('Xác nhận đặt lại'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(
        find.text(
          'Cần xác minh trực tiếp danh tính trước khi đặt lại mật khẩu.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận đặt lại'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Chưa lưu được, hãy thử lại'), findsOneWidget);
      expect(find.text('new-password'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('admin list filters pending and handled requests', (
    tester,
  ) async {
    final dio = testDio((options) {
      if (options.queryParameters['status'] == 'RESOLVED') {
        return jsonResponse([]);
      }
      return jsonResponse([
        {
          'id': 5,
          'name': 'Nhân viên',
          'phone': '0901000003',
          'requestedName': 'Tên tự khai',
          'status': 'PENDING',
          'createdAt': '2026-11-05T10:00:00',
        },
      ]);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PasswordSupportScreen(dio: dio),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nhân viên · 0901000003'), findsOneWidget);
    expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã đặt lại').last);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có yêu cầu'), findsOneWidget);
    expect(find.text('Nhân viên · 0901000003'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
