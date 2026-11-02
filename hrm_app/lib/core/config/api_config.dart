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
        // USB development: adb -s <serial> reverse tcp:8080 tcp:8080.
        // For Wi-Fi or a deployed server, override API_BASE_URL explicitly.
        return 'http://127.0.0.1:8080/api';
      }
    } catch (_) {}
  }
  return 'http://10.0.2.2:8080/api'; // Default for Android Emulator
}
