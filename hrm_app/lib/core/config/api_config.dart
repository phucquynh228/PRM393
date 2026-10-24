import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

String globalBaseUrl = 'http://10.0.2.2:8080/api';

Future<String> determineBaseUrl() async {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return 'http://localhost:8080/api';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo.timeout(
        const Duration(milliseconds: 500),
      );
      if (androidInfo.isPhysicalDevice) {
        return 'http://10.33.75.228:8080/api'; // Host PC Wi-Fi IP for physical device
      }
    } catch (_) {}
  }
  return 'http://10.0.2.2:8080/api'; // Default for Android Emulator
}
