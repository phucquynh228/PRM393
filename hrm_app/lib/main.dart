import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/services/device_info_service.dart';
import 'core/services/location_service.dart';
import 'data/remote/api_client.dart';
import 'data/repositories/attendance_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/usecases/check_in_usecase.dart';
import 'domain/usecases/check_out_usecase.dart';
import 'domain/usecases/get_attendance_history_usecase.dart';
import 'domain/usecases/get_schedules_usecase.dart';
import 'domain/usecases/login_usecase.dart';
import 'presentation/blocs/home/home_bloc.dart';
import 'presentation/blocs/login/login_bloc.dart';
import 'presentation/screens/login_screen.dart';

String globalBaseUrl = 'http://10.0.2.2:8080/api';

Future<String> _determineBaseUrl() async {
  if (kIsWeb) return 'http://localhost:8080/api';
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo.timeout(
        const Duration(seconds: 2),
      );
      if (androidInfo.isPhysicalDevice) {
        return 'http://10.33.75.228:8080/api'; // IP Wi-Fi máy tính dành cho Máy thật
      }
    } catch (_) {}
  }
  return 'http://10.0.2.2:8080/api'; // Mặc định cho Android Emulator
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  globalBaseUrl = await _determineBaseUrl();

  const secureStorage = FlutterSecureStorage();
  final deviceInfoService = DeviceInfoService();
  final locationService = LocationService();

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
  ));

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
  final getSchedulesUseCase = GetSchedulesUseCase(attendanceRepository);
  final checkInUseCase = CheckInUseCase(attendanceRepository);
  final checkOutUseCase = CheckOutUseCase(attendanceRepository);
  final getAttendanceHistoryUseCase = GetAttendanceHistoryUseCase(attendanceRepository);

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<LoginBloc>(
          create: (_) => LoginBloc(loginUseCase: loginUseCase),
        ),
        BlocProvider<HomeBloc>(
          create: (_) => HomeBloc(
            getSchedulesUseCase: getSchedulesUseCase,
            checkInUseCase: checkInUseCase,
            checkOutUseCase: checkOutUseCase,
            getAttendanceHistoryUseCase: getAttendanceHistoryUseCase,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HRM Cafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
