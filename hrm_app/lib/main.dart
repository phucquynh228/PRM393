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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStorage = FlutterSecureStorage();
  final deviceInfoService = DeviceInfoService();
  final locationService = LocationService();

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

  // - Dùng 'http://10.0.2.2:8080/api' nếu chạy trên Android Emulator.
  // - Nếu chạy trên MÁY THẬT qua cáp USB: Chạy lệnh 'adb reverse tcp:8080 tcp:8080' trong Terminal.
  // - Hoặc đổi thành IP Wi-Fi của máy tính (VD: 'http://10.33.75.228:8080/api').
  final apiClient = ApiClient(dio, baseUrl: 'http://10.0.2.2:8080/api');

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
