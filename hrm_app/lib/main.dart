import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/services/device_info_service.dart';
import 'core/services/location_service.dart';
import 'data/remote/api_client.dart';
import 'data/repositories/attendance_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/usecases/check_in_usecase.dart';
import 'domain/usecases/get_schedules_usecase.dart';
import 'domain/usecases/login_usecase.dart';
import 'presentation/blocs/home/home_bloc.dart';
import 'presentation/blocs/login/login_bloc.dart';
import 'presentation/screens/login_screen.dart';

Future<bool> _checkIsEmulator() async {
  if (!Platform.isAndroid) return false;
  try {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (!androidInfo.isPhysicalDevice) return true;

    final model = androidInfo.model.toLowerCase();
    final product = androidInfo.product.toLowerCase();
    final hardware = androidInfo.hardware.toLowerCase();
    final brand = androidInfo.brand.toLowerCase();
    final fingerprint = androidInfo.fingerprint.toLowerCase();

    if (model.contains('gphone') ||
        model.contains('emulator') ||
        model.contains('sdk') ||
        product.contains('sdk') ||
        product.contains('gphone') ||
        hardware.contains('goldfish') ||
        hardware.contains('ranchu') ||
        brand.contains('generic') ||
        fingerprint.contains('generic')) {
      return true;
    }
  } catch (_) {}
  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStorage = FlutterSecureStorage();
  final deviceInfoService = DeviceInfoService();
  final locationService = LocationService();

  // Kiểm tra chính xác xem có phải là Giả lập Emulator hay không
  final isEmulator = await _checkIsEmulator();
  final String baseUrl = isEmulator
      ? 'http://10.0.2.2:8080/api'      // Dành cho Android Emulator
      : 'http://10.33.75.228:8080/api';  // Dành cho Máy thật (IP Wi-Fi của máy tính)

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secureStorage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ),
  );

  final apiClient = ApiClient(dio, baseUrl: baseUrl);

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
