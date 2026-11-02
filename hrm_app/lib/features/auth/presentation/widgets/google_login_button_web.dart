import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/features/auth/data/services/google_sign_in_service.dart';

class GoogleLoginButton extends StatefulWidget {
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
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  bool _ready = false, _loading = false;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _initialize({bool reportError = false}) async {
    if (_loading || _ready) return;
    _loading = true;
    try {
      await context.read<GoogleSignInService>().initialize();
      if (!mounted) return;
      _events = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn && !widget.busy) {
            final token = event.user.authentication.idToken;
            if (token == null || token.isEmpty) {
              widget.onError(
                'Chưa nhận được xác thực Google. Vui lòng thử lại.',
              );
            } else {
              widget.onIdToken(token);
            }
          }
        },
        onError: (Object e) {
          if (mounted && !widget.busy) widget.onError(googleSignInError(e));
        },
      );
      setState(() => _ready = true);
    } catch (e) {
      if (mounted && reportError) widget.onError(readableApiError(e));
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) => !_ready
      ? OutlinedButton.icon(
          onPressed: widget.busy ? null : () => _initialize(reportError: true),
          icon: Image.asset(
            'assets/google_g.png',
            width: 20,
            height: 20,
            excludeFromSemantics: true,
          ),
          label: const Text('Đăng nhập bằng Google'),
        )
      : IgnorePointer(
          ignoring: widget.busy,
          child: Opacity(
            opacity: widget.busy ? .5 : 1,
            child: SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.center,
                child: web.renderButton(
                  configuration: web.GSIButtonConfiguration(
                    type: web.GSIButtonType.standard,
                    theme: web.GSIButtonTheme.outline,
                    size: web.GSIButtonSize.large,
                    text: web.GSIButtonText.signinWith,
                    shape: web.GSIButtonShape.rectangular,
                    locale: 'vi',
                  ),
                ),
              ),
            ),
          ),
        );
}
