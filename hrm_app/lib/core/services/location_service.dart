import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentPosition({bool rejectMocked = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Dịch vụ vị trí đang tắt. Vui lòng bật GPS.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception(
        'Chưa có quyền vị trí. Vui lòng cấp quyền để lấy tọa độ.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Quyền vị trí bị chặn. Vui lòng mở Cài đặt và cấp quyền cho ứng dụng.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (rejectMocked && !kIsWeb && position.isMocked) {
        throw Exception(
          'Phát hiện vị trí giả lập. Vui lòng tắt ứng dụng giả GPS.',
        );
      }
      return position;
    } catch (e) {
      if (e.toString().startsWith('Exception:')) rethrow;
      throw Exception(
        'Chưa lấy được vị trí hiện tại. Hãy kiểm tra GPS và thử lại.',
      );
    }
  }
}
