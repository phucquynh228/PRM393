import 'package:flutter/material.dart';

class GoogleLoginButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  final ValueChanged<String> onIdToken, onError;
  const GoogleLoginButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.onIdToken,
    required this.onError,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy ? null : onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1F1F1F),
      side: const BorderSide(color: Color(0xFF747775)),
      minimumSize: const Size.fromHeight(48),
    ),
    icon: Image.asset(
      'assets/google_g.png',
      width: 20,
      height: 20,
      excludeFromSemantics: true,
    ),
    label: const Text('Đăng nhập bằng Google', textAlign: TextAlign.center),
  );
}
