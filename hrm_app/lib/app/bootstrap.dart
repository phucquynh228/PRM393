import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hrm_app/core/config/api_config.dart';
import 'package:hrm_app/core/services/device_info_service.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/features/auth/data/services/google_sign_in_service.dart';
import 'package:hrm_app/features/auth/data/repositories/google_auth_repository_impl.dart';
import 'package:hrm_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hrm_app/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:hrm_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/auth/presentation/bloc/login_bloc.dart';
import 'package:hrm_app/shared/data/remote/api_client.dart';

import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  globalBaseUrl = await determineBaseUrl();

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
