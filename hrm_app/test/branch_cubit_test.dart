import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/presentation/blocs/branch/branch_cubit.dart';

import 'support/fakes.dart';

void main() {
  test(
    'staff is read from branch endpoint; report failure keeps other resources',
    () async {
      final paths = <String>[];
      final dio = testDio((o) {
        paths.add(o.path);
        if (o.path == '/manager/branch') {
          return jsonResponse({
            'name': 'Quán A',
            'staff': [
              {'id': 3, 'name': 'An'},
            ],
          });
        }
        return jsonResponse(
          null,
          status: 500,
          success: false,
          message: 'Báo cáo lỗi',
        );
      });
      final cubit = BranchCubit(dio);
      addTearDown(cubit.close);
      addTearDown(dio.close);
      await Future.wait([
        cubit.fetch('branch', '/manager/branch'),
        cubit.fetch('report', '/manager/reports'),
      ]);
      expect(cubit.state.staff.single['id'], 3);
      expect(cubit.state.errors['report'], 'Báo cáo lỗi');
      expect(paths, isNot(contains('/manager/staff')));
    },
  );
  test(
    'slower earlier filter response cannot overwrite latest selection',
    () async {
      final first = Completer<ResponseBody>(),
          second = Completer<ResponseBody>();
      final dio = testDio(
        (o) =>
            o.queryParameters['date'] == 'first' ? first.future : second.future,
      );
      final cubit = BranchCubit(dio);
      addTearDown(cubit.close);
      addTearDown(dio.close);
      final oldRequest = cubit.fetch('attendance', '/manager/attendance', {
        'date': 'first',
      });
      final newRequest = cubit.fetch('attendance', '/manager/attendance', {
        'date': 'second',
      });
      second.complete(jsonResponse({'total': 2, 'items': []}));
      await newRequest;
      first.complete(jsonResponse({'total': 1, 'items': []}));
      await oldRequest;
      expect(cubit.state.attendanceData['total'], 2);
      expect(cubit.state.loading, isEmpty);
    },
  );
}
