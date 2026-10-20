import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/data/remote/api_client.dart';
import 'package:hrm_app/data/repositories/attendance_repository_impl.dart';

import 'support/fakes.dart';

void main() {
  test(
    'history parses attendance id and schedule id from the real API contract',
    () async {
      final paths = <String>[];
      final dio = testDio((o) {
        paths.add(o.path);
        return jsonResponse([
          {
            'id': 42,
            'scheduleId': 7,
            'shiftName': 'Ca sáng',
            'status': 'CHECKED_IN',
            'checkInTime': '2026-10-20T07:00:00',
            'checkOutTime': null,
          },
        ]);
      });
      addTearDown(dio.close);
      final repo = AttendanceRepositoryImpl(
        apiClient: ApiClient(dio),
        locationService: LocationService(),
      );
      final history = await repo.getHistory();
      expect(paths, ['/attendance/history']);
      expect(history.single.id, 42);
      expect(history.single.scheduleId, 7);
      expect(history.single.checkOutTime, isNull);
    },
  );
  test(
    'checkout posts attendance id and rejects unsuccessful responses',
    () async {
      final paths = <String>[];
      final dio = testDio((o) {
        paths.add(o.path);
        return jsonResponse(
          null,
          success: false,
          message: 'Bạn đã check-out rồi',
        );
      });
      addTearDown(dio.close);
      final repo = AttendanceRepositoryImpl(
        apiClient: ApiClient(dio),
        locationService: LocationService(),
      );
      await expectLater(repo.checkOut(42), throwsException);
      expect(paths, ['/attendance/check-out/42']);
    },
  );
}
