import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/admin/data/admin_profile_repository.dart';
import 'package:hrm_app/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:hrm_app/features/admin/presentation/screens/admin_profile_screen.dart';
import 'package:hrm_app/features/admin/presentation/screens/admin_profile_section_screen.dart';
import 'package:hrm_app/features/auth/data/models/login_response.dart';
import 'package:hrm_app/shared/data/remote/api_client.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

import '../../support/fakes.dart';
import '../../presentation/visual_smoke_test.dart' show preview;

class ProfileFixtureCubit extends AdminCubit {
  ProfileFixtureCubit() : super(ApiClient(testDio((_) => jsonResponse([])))) {
    emit(
      const AdminState(
        initialized: true,
        users: [
          {
            'id': 1,
            'name': 'Nguyễn Văn Admin',
            'phone': '0901000001',
            'role': 'ADMIN',
          },
          {'id': 2, 'name': 'Quản lý', 'role': 'MANAGER'},
        ],
      ),
    );
  }
  @override
  Future<void> load() async {}
}

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
    'admin profile contains five destinations and role navigation filters accounts',
    (tester) async {
      final cubit = ProfileFixtureCubit();
      addTearDown(cubit.close);
      String? role;
      await preview(
        tester,
        AdminProfileScreen(
          loginResponse: LoginResponse(
            token: 'test',
            userId: 1,
            name: 'Admin',
            role: 'ADMIN',
          ),
          cubit: cubit,
          repository: AdminProfileRepository(testDio((_) => jsonResponse({}))),
          onManageAccounts: (value) => role = value,
          onShiftTemplates: () {},
          onBranches: () {},
          onLogout: () {},
          onPasswordChanged: () async {},
        ),
        const Size(390, 844),
        'admin-profile-hub',
      );
      expect(find.text('Thông tin cá nhân'), findsOneWidget);
      expect(find.text('Tài khoản và bảo mật'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Cấu hình hệ thống'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cấu hình hệ thống'), findsOneWidget);
      await tester.ensureVisible(find.text('Quản lý tài khoản'));
      await tester.tap(find.text('Quản lý tài khoản'));
      expect(role, '');
      await tester.tap(find.text('Phân quyền hệ thống'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Quản lý'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final managerCard = find.ancestor(
        of: find.text('Quản lý'),
        matching: find.byType(SurfaceCard),
      );
      final manage = find.descendant(
        of: managerCard,
        matching: find.byType(TextButton),
      );
      await tester.ensureVisible(manage);
      await tester.tap(manage);
      expect(role, 'MANAGER');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'security form requires matching passwords and keeps input after server error',
    (tester) async {
      var calls = 0;
      final repository = AdminProfileRepository(
        testDio((options) {
          if (options.method == 'GET') {
            return jsonResponse({
              'id': 1,
              'phone': '0901000001',
              'deviceLinked': true,
            });
          }
          calls++;
          expect(options.data, {
            'currentPassword': 'old-password',
            'newPassword': 'new-password',
          });
          return jsonResponse(
            null,
            status: 400,
            success: false,
            message: 'Mật khẩu hiện tại không đúng',
          );
        }),
      );
      await preview(
        tester,
        AdminProfileSectionScreen(
          section: AdminProfileSection.security,
          repository: repository,
          onProfileChanged: () async {},
          onPasswordChanged: () async {},
          onShiftTemplates: () {},
          onBranches: () {},
        ),
        const Size(390, 1000),
        'admin-profile-security',
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
      await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
      await tester.enterText(find.byType(TextFormField).at(2), 'different');
      final save = find.widgetWithText(FilledButton, 'Đổi mật khẩu');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
      expect(find.text('new-password'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin can change own password without creating a support request',
    (tester) async {
      var changed = false;
      final paths = <String>[];
      final repository = AdminProfileRepository(
        testDio((options) {
          paths.add(options.path);
          if (options.method == 'GET') {
            return jsonResponse({'id': 1, 'phone': '0901000001'});
          }
          expect(options.path, endsWith('/admin/profile/password'));
          expect(options.data, {
            'currentPassword': 'old-password',
            'newPassword': 'new-password',
          });
          return jsonResponse(null);
        }),
      );
      await preview(
        tester,
        AdminProfileSectionScreen(
          section: AdminProfileSection.security,
          repository: repository,
          onProfileChanged: () async {},
          onPasswordChanged: () async {
            changed = true;
          },
          onShiftTemplates: () {},
          onBranches: () {},
        ),
        const Size(390, 844),
        'admin-change-own-password',
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
      await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
      await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
      final save = find.widgetWithText(FilledButton, 'Đổi mật khẩu');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(paths.any((p) => p.contains('password-support')), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system settings validate reminder and persist the selected value',
    (tester) async {
      int? saved;
      final repository = AdminProfileRepository(
        testDio((options) {
          if (options.method == 'PUT') {
            saved = options.data['reminderMinutes'] as int;
          }
          return jsonResponse({
            'reminderMinutes': saved ?? 10,
            'timezone': 'Asia/Ho_Chi_Minh',
            'maxCheckoutHours': 24,
          });
        }),
      );
      await preview(
        tester,
        AdminProfileSectionScreen(
          section: AdminProfileSection.settings,
          repository: repository,
          onProfileChanged: () async {},
          onPasswordChanged: () async {},
          onShiftTemplates: () {},
          onBranches: () {},
        ),
        const Size(390, 844),
        'admin-profile-settings',
      );
      await tester.enterText(find.byType(TextFormField), '0');
      final save = find.text('Lưu thay đổi');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await tester.enterText(find.byType(TextFormField), '15');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, 15);
      expect(tester.takeException(), isNull);
    },
  );
}
