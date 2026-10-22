import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/services/device_info_service.dart';
import 'package:hrm_app/core/services/google_sign_in_service.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/data/models/login_response.dart';
import 'package:hrm_app/data/repositories/google_auth_repository_impl.dart';
import 'package:hrm_app/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/domain/repositories/auth_repository.dart';
import 'package:hrm_app/domain/repositories/google_auth_repository.dart';
import 'package:hrm_app/domain/usecases/login_usecase.dart';
import 'package:hrm_app/presentation/blocs/login/login_bloc.dart';
import 'package:hrm_app/presentation/blocs/login/login_event.dart';
import 'package:hrm_app/presentation/blocs/login/login_state.dart';
import 'package:hrm_app/presentation/screens/login_screen.dart';
import 'package:hrm_app/presentation/screens/google_link_dialog.dart';
import 'package:hrm_app/presentation/screens/employee/staff_screen.dart';

import 'support/fakes.dart';
import 'visual_smoke_test.dart' show preview;

final googleTestLogin = LoginResponse(
  token: 'hrm-jwt',
  userId: 3,
  name: 'Nhân viên',
  role: 'STAFF',
);

class GoogleFakePhoneAuth implements AuthRepository {
  @override
  Future<LoginResponse> login(String phone, String password) async =>
      googleTestLogin;
  @override
  Future<bool> isLoggedIn() async => false;
  @override
  Future<void> logout() async {}
}

class FakeGoogleAuth implements GoogleAuthRepository {
  String? token = 'google-id-token';
  bool needsLink = true;
  Object? linkError;
  int selections = 0, exchanges = 0, links = 0;
  Completer<String?>? selectionGate;
  @override
  Future<String?> selectAccount() async {
    selections++;
    return selectionGate?.future ?? token;
  }

  @override
  Future<GoogleLoginResult> login(String token) async {
    exchanges++;
    return GoogleLoginResult(
      linkRequired: needsLink,
      email: 'person@gmail.com',
      login: needsLink ? null : googleTestLogin,
    );
  }

  @override
  Future<LoginResponse> link(
    String token,
    String phone,
    String password,
  ) async {
    links++;
    if (linkError != null) throw linkError!;
    return googleTestLogin;
  }
}

class GoogleTestDevice extends DeviceInfoService {
  @override
  Future<String> getDeviceId() async => 'test-device';
}

Future<void> flushBloc() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() async {
    await (FontLoader(
      'HRMSans',
    )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('google-login-phone', (tester) async {
    final bloc = LoginBloc(
      loginUseCase: LoginUseCase(GoogleFakePhoneAuth()),
      googleAuth: FakeGoogleAuth(),
    );
    addTearDown(bloc.close);
    await preview(
      tester,
      BlocProvider.value(value: bloc, child: const LoginScreen()),
      const Size(390, 844),
      'google-login-phone',
    );
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
  });

  testWidgets('google-link-small-large-text', (tester) async {
    final bloc = LoginBloc(
      loginUseCase: LoginUseCase(GoogleFakePhoneAuth()),
      googleAuth: FakeGoogleAuth(),
    );
    addTearDown(bloc.close);
    bloc.add(const GoogleLoginPressed());
    await tester.pump();
    await tester.pump();
    await preview(
      tester,
      BlocProvider.value(value: bloc, child: const GoogleLinkDialog()),
      const Size(320, 740),
      'google-link-small-large-text',
      scale: 1.6,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'canceling Google chooser leaves login usable and never calls backend',
    () async {
      final google = FakeGoogleAuth()..token = null;
      final bloc = LoginBloc(
        loginUseCase: LoginUseCase(GoogleFakePhoneAuth()),
        googleAuth: google,
      );
      addTearDown(bloc.close);
      bloc.add(const GoogleLoginPressed());
      await flushBloc();
      await flushBloc();
      expect(bloc.state, isA<LoginInitial>());
      expect(google.exchanges, 0);
      bloc.add(
        const LoginButtonPressed(phone: '0901000003', password: '123456'),
      );
      await flushBloc();
      expect(bloc.state, isA<LoginSuccess>());
    },
  );

  test('simultaneous Google presses and phone submit cannot start duplicate logins', () async {
    final google = FakeGoogleAuth()..selectionGate = Completer<String?>();
    final bloc = LoginBloc(
      loginUseCase: LoginUseCase(GoogleFakePhoneAuth()),
      googleAuth: google,
    );
    addTearDown(bloc.close);
    bloc.add(const GoogleLoginPressed());
    bloc.add(const GoogleLoginPressed());
    bloc.add(const LoginButtonPressed(phone: '0901000003', password: '123456'));
    await flushBloc();
    expect(google.selections, 1);
    expect(bloc.state, isA<LoginLoading>());
    google.selectionGate!.complete(null);
    await flushBloc();
  });

  test('web identity token skips native chooser and successful login can reset after logout', () async {
    final google = FakeGoogleAuth()..needsLink = false;
    final bloc = LoginBloc(
      loginUseCase: LoginUseCase(GoogleFakePhoneAuth()),
      googleAuth: google,
    );
    addTearDown(bloc.close);
    bloc.add(const GoogleLoginPressed(idToken: 'web-token'));
    await flushBloc();
    await flushBloc();
    expect(google.selections, 0);
    expect((bloc.state as LoginSuccess).loginResponse.role, 'STAFF');
    bloc.add(LoginScreenOpened());
    await flushBloc();
    expect(bloc.state, isA<LoginInitial>());
    bloc.add(const GoogleLoginPressed(idToken: 'web-token'));
    await flushBloc();
    await flushBloc();
    expect(google.exchanges, 2);
    expect(bloc.state, isA<LoginSuccess>());
  });

  test(
    'unlinked identity never stores Google ID token as an application JWT',
    () async {
      final dio = testDio(
        (_) => jsonResponse({
          'linkRequired': true,
          'email': 'person@gmail.com',
          'login': null,
        }),
      );
      addTearDown(dio.close);
      const storage = FlutterSecureStorage();
      final repo = GoogleAuthRepositoryImpl(
        dio: dio,
        google: GoogleSignInService(dio),
        device: GoogleTestDevice(),
        storage: storage,
      );
      final result = await repo.login('google-id-token');
      expect(result.linkRequired, isTrue);
      expect(await storage.read(key: 'jwt_token'), isNull);
    },
  );

  test(
    'link posts verified identity and credentials then stores only backend JWT',
    () async {
      final dio = testDio((o) {
        expect(o.path, '/auth/google/link');
        expect(o.data['idToken'], 'google-id-token');
        expect(o.data['deviceId'], 'test-device');
        expect(o.data['phone'], '0901000003');
        expect(o.data['password'], '123456');
        return jsonResponse(googleTestLogin.toJson());
      });
      addTearDown(dio.close);
      const storage = FlutterSecureStorage();
      final repo = GoogleAuthRepositoryImpl(
        dio: dio,
        google: GoogleSignInService(dio),
        device: GoogleTestDevice(),
        storage: storage,
      );
      await repo.link('google-id-token', '0901000003', '123456');
      expect(await storage.read(key: 'jwt_token'), 'hrm-jwt');
    },
  );

  testWidgets(
    'Google link form keeps entered credentials when password is wrong and can cancel',
    (tester) async {
      final google = FakeGoogleAuth()
        ..linkError = Exception('Số điện thoại hoặc mật khẩu không đúng');
      final bloc = LoginBloc(
        loginUseCase: LoginUseCase(GoogleFakePhoneAuth()),
        googleAuth: google,
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.tap(find.text('Đăng nhập bằng Google'));
      await tester.pumpAndSettle();
      expect(find.text('Liên kết tài khoản Google'), findsOneWidget);
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), '0901000003');
      await tester.enterText(fields.at(1), 'incorrect');
      await tester.tap(find.text('Liên kết và đăng nhập'));
      await tester.pumpAndSettle();
      expect(
        find.text('Số điện thoại hoặc mật khẩu không đúng'),
        findsOneWidget,
      );
      expect(find.text('0901000003'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(bloc.state, isA<LoginInitial>());
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'link success closes dialog and routes to Staff using existing app session',
    (tester) async {
      final google = FakeGoogleAuth();
      final dio = testDio(
        (_) => jsonResponse({
          'profile': {'name': 'Nhân viên'},
          'today': [],
          'schedules': [],
          'attendance': [],
          'requests': [],
          'notifications': [],
        }),
      );
      final bloc = LoginBloc(
        loginUseCase: LoginUseCase(GoogleFakePhoneAuth()),
        googleAuth: google,
      );
      addTearDown(bloc.close);
      addTearDown(dio.close);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<Dio>.value(value: dio),
            RepositoryProvider<AttendanceRepository>.value(
              value: FakeAttendanceRepository(),
            ),
          ],
          child: BlocProvider.value(
            value: bloc,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const LoginScreen(),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Đăng nhập bằng Google'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), '0901000003');
      await tester.enterText(fields.at(1), '123456');
      await tester.tap(find.text('Liên kết và đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffScreen), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(google.links, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
