import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/data/models/login_response.dart';
import 'package:hrm_app/domain/repositories/auth_repository.dart';
import 'package:hrm_app/domain/usecases/login_usecase.dart';
import 'package:hrm_app/presentation/blocs/login/login_bloc.dart';
import 'package:hrm_app/presentation/screens/login_screen.dart';
import 'package:hrm_app/presentation/screens/admin/dialogs/user_form_dialog.dart';
import 'package:hrm_app/presentation/widgets/app_shell.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<LoginResponse> login(String phone, String password) async =>
      throw Exception('Sai thông tin đăng nhập');
  @override
  Future<bool> isLoggedIn() async => false;
  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('login validates fields inline and displays server error', (
    tester,
  ) async {
    final bloc = LoginBloc(loginUseCase: LoginUseCase(FakeAuthRepository()));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider.value(value: bloc, child: const LoginScreen()),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập số điện thoại hợp lệ'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '0901000003');
    await tester.enterText(find.byType(TextFormField).at(1), 'incorrect');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Sai thông tin đăng nhập'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('navigation adapts between phone and wide screen', (
    tester,
  ) async {
    Widget shell() => MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppShell(
        title: 'HRM Cafe',
        subtitle: 'Nhân viên',
        selectedIndex: 0,
        destinations: const [
          AppDestination('Hôm nay', Icons.home_outlined),
          AppDestination('Yêu cầu', Icons.mail_outline),
        ],
        onDestinationSelected: (_) {},
        onLogout: () {},
        child: const Text('Nội dung'),
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shell());
    expect(find.byType(NavigationBar), findsOneWidget);
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
  testWidgets('account form keeps input when saving fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => UserFormDialog.show(
                context,
                stores: const [],
                showSnackBar: (_, {bool isError = false}) {},
                onSubmit: (_) async =>
                    throw Exception('Số điện thoại đã tồn tại'),
              ),
              child: const Text('Mở form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn An');
    await tester.enterText(find.byType(TextFormField).at(1), '0901000003');
    await tester.enterText(find.byType(TextFormField).at(2), 'abcdef');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Số điện thoại đã tồn tại'), findsOneWidget);
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.byType(UserFormDialog), findsOneWidget);
  });
  test('light theme text and status colors meet small-text contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    final theme = AppTheme.lightTheme;
    for (final style in [
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.titleLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.headlineMedium,
    ]) {
      expect(style!.color, isNotNull);
      expect(
        contrast(style.color!, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    }
    for (final pair in [
      (AppColors.success, AppColors.successBg),
      (AppColors.warning, AppColors.warningBg),
      (AppColors.error, AppColors.errorBg),
      (AppColors.info, AppColors.infoBg),
    ]) {
      expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
  });
}
