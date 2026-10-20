import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/domain/usecases/check_in_usecase.dart';
import 'package:hrm_app/domain/usecases/check_out_usecase.dart';
import 'package:hrm_app/domain/usecases/get_schedules_usecase.dart';
import 'package:hrm_app/domain/usecases/get_attendance_history_usecase.dart';
import 'package:hrm_app/presentation/blocs/home/home_bloc.dart';
import 'package:hrm_app/presentation/blocs/home/home_event.dart';
import 'package:hrm_app/presentation/blocs/home/home_state.dart';

import 'support/fakes.dart';

HomeBloc makeHomeBloc(FakeAttendanceRepository repo) => HomeBloc(
  getSchedulesUseCase: GetSchedulesUseCase(repo),
  checkInUseCase: CheckInUseCase(repo),
  checkOutUseCase: CheckOutUseCase(repo),
  getAttendanceHistoryUseCase: GetAttendanceHistoryUseCase(repo),
);
Future<void> loadHome(HomeBloc bloc) async {
  final done = bloc.stream.firstWhere((s) => s.initialized && !s.loading);
  bloc.add(LoadSchedules());
  await done;
}

void main() {
  test('checkout calls repository with attendance record id and reports success after completion', () async {
    final repo = FakeAttendanceRepository();
    final bloc = makeHomeBloc(repo);
    addTearDown(bloc.close);
    await loadHome(bloc);
    final done = bloc.stream.firstWhere((s) => s.message != null);
    bloc.add(const CheckOutRequested(attendanceId: 42));
    await done;
    expect(repo.checkoutCalls, [42]);
    expect(bloc.state.busy, false);
  });
  test('failed checkout preserves schedules and never emits success', () async {
    final repo = FakeAttendanceRepository()..failCheckout = true;
    final bloc = makeHomeBloc(repo);
    addTearDown(bloc.close);
    await loadHome(bloc);
    final states = <HomeState>[];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);
    final done = bloc.stream.firstWhere((s) => s.error != null);
    bloc.add(const CheckOutRequested(attendanceId: 42));
    await done;
    expect(bloc.state.schedules.single.resolvedId, 7);
    expect(states.any((s) => s.message != null), false);
    expect(bloc.state.busy, false);
  });
  test('invalid checkout id does not reach API', () async {
    final repo = FakeAttendanceRepository();
    final bloc = makeHomeBloc(repo);
    addTearDown(bloc.close);
    await loadHome(bloc);
    final done = bloc.stream.firstWhere((s) => s.error != null);
    bloc.add(const CheckOutRequested(attendanceId: 0));
    await done;
    expect(repo.checkoutCalls, isEmpty);
  });
  test('repeated taps while checkout is pending submit only once', () async {
    final repo = FakeAttendanceRepository()..checkoutGate = Completer<void>();
    final bloc = makeHomeBloc(repo);
    addTearDown(bloc.close);
    await loadHome(bloc);
    final busy = bloc.stream.firstWhere((s) => s.busy);
    bloc.add(const CheckOutRequested(attendanceId: 42));
    await busy;
    bloc.add(const CheckOutRequested(attendanceId: 42));
    await Future<void>.delayed(Duration.zero);
    expect(repo.checkoutCalls, [42]);
    final done = bloc.stream.firstWhere((s) => s.message != null);
    repo.checkoutGate!.complete();
    await done;
  });
  test('refresh failure preserves previously loaded schedules', () async {
    final repo = FakeAttendanceRepository();
    final bloc = makeHomeBloc(repo);
    addTearDown(bloc.close);
    await loadHome(bloc);
    repo.failLoad = true;
    final done = bloc.stream.firstWhere((s) => s.error != null);
    bloc.add(LoadSchedules());
    await done;
    expect(bloc.state.schedules, isNotEmpty);
    expect(bloc.state.initialized, true);
  });
}
