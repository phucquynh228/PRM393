import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:hrm_app/core/services/google_sign_in_service.dart';

import 'support/fakes.dart';

class TestGooglePlatform extends GoogleSignInPlatform {
  Object? cleanupError;
  Object? authenticationError;
  int authentications = 0;
  InitParameters? configuration;

  @override
  Future<void> init(InitParameters params) async => configuration = params;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<void> signOut(SignOutParams params) async {
    if (cleanupError != null) throw cleanupError!;
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authentications++;
    if (authenticationError != null) throw authenticationError!;
    return const AuthenticationResults(
      user: GoogleSignInUserData(
        email: 'person@gmail.com',
        id: 'google-subject',
      ),
      authenticationTokens: AuthenticationTokenData(idToken: 'google-id-token'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestGooglePlatform platform;
  late GoogleSignInPlatform originalPlatform;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    originalPlatform = GoogleSignInPlatform.instance;
    platform = TestGooglePlatform();
    GoogleSignInPlatform.instance = platform;
  });

  tearDown(() {
    GoogleSignInPlatform.instance = originalPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  GoogleSignInService service({
    String clientId = '1234567890-test.apps.googleusercontent.com',
  }) {
    final dio = testDio(
      (_) => jsonResponse({'enabled': true, 'clientId': clientId}),
    );
    addTearDown(dio.close);
    return GoogleSignInService(dio);
  }

  PlatformException clearFailure() => PlatformException(
    code: 'Clear Failed',
    message: 'clearCredentialStateAsync no provider dependencies found',
  );

  test('failed credential cleanup still opens authentication', () async {
    platform.cleanupError = clearFailure();

    expect(await service().selectAccount(), 'google-id-token');
    expect(platform.authentications, 1);
    expect(
      platform.configuration?.serverClientId,
      '1234567890-test.apps.googleusercontent.com',
    );
  });

  test('documentation placeholder cannot open Google authentication', () async {
    await expectLater(
      service(clientId: 'DAN_WEB_CLIENT_ID_CUA_BAN.apps.googleusercontent.com')
          .selectAccount(),
      throwsA(
        predicate(
          (Object e) =>
              e.toString().contains(GoogleSignInService.notConfigured),
        ),
      ),
    );
    expect(platform.configuration, isNull);
    expect(platform.authentications, 0);
  });

  test('unavailable provider explains how to repair the device', () async {
    platform.cleanupError = clearFailure();
    platform.authenticationError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.providerConfigurationError,
      description: 'getCredentialAsync no provider dependencies found',
    );

    await expectLater(
      service().selectAccount(),
      throwsA(
        predicate(
          (Object e) =>
              e.toString().contains(GoogleSignInService.providerUnavailable) &&
              !e.toString().contains('PlatformException'),
        ),
      ),
    );
    expect(platform.authentications, 1);
  });

  test(
    'canceling authentication after a cleanup failure is still silent',
    () async {
      platform.cleanupError = clearFailure();
      platform.authenticationError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      expect(await service().selectAccount(), isNull);
      expect(platform.authentications, 1);
    },
  );

  test(
    'unrelated platform failures are not ignored or shown verbatim',
    () async {
      platform.cleanupError = PlatformException(
        code: 'channel-error',
        message: 'Internal native details',
      );

      await expectLater(
        service().selectAccount(),
        throwsA(
          predicate(
            (Object e) =>
                e.toString().contains('Chưa thể mở đăng nhập Google') &&
                !e.toString().contains('Internal native details'),
          ),
        ),
      );
      expect(platform.authentications, 0);
    },
  );

  test(
    'OAuth client errors retain the separate configuration message',
    () async {
      platform.authenticationError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );

      await expectLater(
        service().selectAccount(),
        throwsA(
          predicate(
            (Object e) => e.toString().contains('chưa được cấu hình đúng'),
          ),
        ),
      );
    },
  );
}
