import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/auth/data/models/login_response.dart';
import 'package:hrm_app/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:hrm_app/features/branch/presentation/screens/manager_profile_screen.dart';

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

  testWidgets(
    'manager profile edits own account, refreshes identity and changes password through manager API',
    (tester) async {
      var profile = <String, dynamic>{
        'id': 2,
        'name': 'Trần Thị Manager',
        'phone': '0901000002',
        'role': 'MANAGER',
        'email': 'manager@example.com',
        'storeName': 'Cafe Thủ Đức',
        'storeCode': 'HCM-TD01',
        'employeeCode': 'NV-0002',
        'employmentStatus': 'ACTIVE',
      };
      final paths = <String>[];
      final dio = testDio((o) {
        paths.add('${o.method} ${o.path}');
        if (o.method == 'PUT' && o.path == '/manager/profile') {
          profile = {...profile, ...Map<String, dynamic>.from(o.data as Map)};
        }
        return jsonResponse(
          o.path == '/manager/branch' ? {'name': 'Cafe Thủ Đức'} : profile,
        );
      });
      final cubit = BranchCubit(dio);
      addTearDown(cubit.close);
      addTearDown(dio.close);
      await preview(
        tester,
        ManagerProfileScreen(
          loginResponse: LoginResponse(
            token: 'test',
            userId: 2,
            name: 'Old Name',
            role: 'MANAGER',
          ),
          cubit: cubit,
          onLogout: () {},
        ),
        const Size(390, 844),
        'manager-profile-hub',
      );
      expect(find.text('Trần Thị Manager'), findsOneWidget);
      expect(find.text('Quản lý tài khoản'), findsNothing);
      expect(find.text('Phân quyền hệ thống'), findsNothing);

      await tester.tap(find.text('Thông tin cá nhân'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cập nhật thông tin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cập nhật thông tin'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Quản lý mới');
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(paths, contains('PUT /manager/profile'));
      expect(find.text('Quản lý mới'), findsWidgets);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Quản lý mới'), findsOneWidget);

      await tester.tap(find.text('Tài khoản và bảo mật'));
      await tester.pumpAndSettle();
      expect(find.text('0901000002'), findsOneWidget);
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
      expect(paths, contains('PUT /manager/password'));
      expect(
        paths.any((p) => p.contains('/staff/') || p.contains('/admin/')),
        isFalse,
      );
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
        '0901000002',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manager profile fits small phone with large text', (
    tester,
  ) async {
    final dio = testDio(
      (_) => jsonResponse({
        'id': 2,
        'name': 'Trần Thị Manager',
        'role': 'MANAGER',
        'phone': '0901000002',
      }),
    );
    final cubit = BranchCubit(dio);
    addTearDown(cubit.close);
    addTearDown(dio.close);
    await preview(
      tester,
      ManagerProfileScreen(
        loginResponse: LoginResponse(
          token: 'test',
          userId: 2,
          name: 'Manager',
          role: 'MANAGER',
        ),
        cubit: cubit,
        onLogout: () {},
      ),
      const Size(320, 740),
      'manager-profile-large-text',
      scale: 1.6,
    );
    await tester.ensureVisible(find.text('Thông tin công việc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông tin công việc'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
