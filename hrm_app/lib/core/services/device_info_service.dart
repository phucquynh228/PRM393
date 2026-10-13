import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getDeviceId() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo.timeout(const Duration(seconds: 3));
        return 'web_${webInfo.vendor}_${webInfo.userAgent.hashCode}';
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo.timeout(const Duration(seconds: 3));
        return androidInfo.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo.timeout(const Duration(seconds: 3));
        return iosInfo.identifierForVendor ?? 'unknown_ios_id';
      } else {
        return 'desktop_device_id';
      }
    } catch (e) {
      return 'emulator_device_id';
    }
  }
}
