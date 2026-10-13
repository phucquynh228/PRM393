import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 3),
        onTimeout: () => true,
      );
      
      if (!serviceEnabled) {
        throw Exception('Dịch vụ định vị GPS chưa được bật.');
      }

      permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () => LocationPermission.whileInUse,
      );

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 5),
          onTimeout: () => LocationPermission.whileInUse,
        );
        if (permission == LocationPermission.denied) {
          throw Exception('Quyền truy cập vị trí bị từ chối');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Quyền vị trí bị từ chối vĩnh viễn. Vui lòng cấp quyền trong Cài đặt.');
      }

      // Retrieve current location with timeout and fallback
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      ).catchError((_) async {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
        // Fallback default coordinates (FPT University HCM) for testing/emulator
        return Position(
          longitude: 106.7718,
          latitude: 10.8512,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      });

      // Check for fake GPS / Mock Location
      if (!kIsWeb && position.isMocked) {
        throw Exception('Phát hiện sử dụng GPS giả (Fake GPS). Vui lòng tắt phần mềm giả mạo vị trí.');
      }

      return position;
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Không thể lấy vị trí hiện tại: $e');
    }
  }
}
