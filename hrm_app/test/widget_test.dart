import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrm_app/main.dart';
import 'package:hrm_app/presentation/blocs/login/login_bloc.dart';
import 'package:hrm_app/domain/usecases/login_usecase.dart';
import 'package:hrm_app/domain/repositories/auth_repository.dart';
import 'package:hrm_app/data/models/login_response.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<LoginResponse> login(String phone, String password) async {
    return LoginResponse(
      token: 'fake_token',
      userId: 1,
      name: 'Test User',
      role: 'STAFF',
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<bool> isLoggedIn() async => false;
}

void main() {
  testWidgets('App renders LoginScreen correctly', (WidgetTester tester) async {
    final fakeRepo = FakeAuthRepository();
    final loginUseCase = LoginUseCase(fakeRepo);

    await tester.pumpWidget(
      BlocProvider<LoginBloc>(
        create: (_) => LoginBloc(loginUseCase: loginUseCase),
        child: const MyApp(),
      ),
    );

    expect(find.text('HRM Cafe'), findsOneWidget);
    expect(find.text('Đăng Nhập'), findsOneWidget);
  });
}
