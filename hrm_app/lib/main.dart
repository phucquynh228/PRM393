import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/services/device_info_service.dart';
import 'core/services/google_sign_in_service.dart';
import 'data/repositories/google_auth_repository_impl.dart';
import 'core/services/location_service.dart';
import 'data/remote/api_client.dart';
import 'data/repositories/attendance_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/repositories/attendance_repository.dart';
import 'presentation/blocs/login/login_bloc.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/login_screen.dart';

String globalBaseUrl = 'http://10.0.2.2:8080/api';

Future<String> _determineBaseUrl() async {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return 'http://localhost:8080/api';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo.timeout(
        const Duration(milliseconds: 500),
      );
      if (androidInfo.isPhysicalDevice) {
        return 'http://10.33.75.228:8080/api'; // Host PC Wi-Fi IP for physical device
      }
    } catch (_) {}
  }
  return 'http://10.0.2.2:8080/api'; // Default for Android Emulator
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  globalBaseUrl = await _determineBaseUrl();

  const secureStorage = FlutterSecureStorage();
  final deviceInfoService = DeviceInfoService();
  final locationService = LocationService();

  final dio = Dio(
    BaseOptions(
      baseUrl: globalBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await secureStorage
              .read(key: 'jwt_token')
              .timeout(const Duration(seconds: 2));
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {}
        return handler.next(options);
      },
    ),
  );

  final apiClient = ApiClient(dio, baseUrl: globalBaseUrl);

  final authRepository = AuthRepositoryImpl(
    apiClient: apiClient,
    deviceInfoService: deviceInfoService,
    secureStorage: secureStorage,
  );

  final attendanceRepository = AttendanceRepositoryImpl(
    apiClient: apiClient,
    locationService: locationService,
  );

  final loginUseCase = LoginUseCase(authRepository);
  final googleSignIn = GoogleSignInService(dio);
  final googleAuth = GoogleAuthRepositoryImpl(
    dio: dio,
    google: googleSignIn,
    device: deviceInfoService,
    storage: secureStorage,
  );
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<Dio>.value(value: dio),
        RepositoryProvider<GoogleSignInService>.value(value: googleSignIn),
        RepositoryProvider<AttendanceRepository>.value(
          value: attendanceRepository,
        ),
      ],
      child: BlocProvider<LoginBloc>(
        create: (_) =>
            LoginBloc(loginUseCase: loginUseCase, googleAuth: googleAuth),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HRM Cafe - Management Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginScreen(),
    );
  }
}
