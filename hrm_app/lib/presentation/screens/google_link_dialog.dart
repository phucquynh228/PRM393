import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/login/login_bloc.dart';
import '../blocs/login/login_event.dart';
import '../blocs/login/login_state.dart';
import '../widgets/adaptive_form.dart';
import '../widgets/content_widgets.dart';

class GoogleLinkDialog extends StatefulWidget {
  final String initialPhone;
  const GoogleLinkDialog({super.key, this.initialPhone = ''});
  @override
  State<GoogleLinkDialog> createState() => _GoogleLinkDialogState();
}

class _GoogleLinkDialogState extends State<GoogleLinkDialog> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _password = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final state = context.read<LoginBloc>().state;
    if (state is! GoogleLinkRequired ||
        state.submitting ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<LoginBloc>().add(
      GoogleLinkSubmitted(phone: _phone.text.trim(), password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<LoginBloc, LoginState>(
    builder: (context, state) {
      final busy = state is GoogleLinkRequired && state.submitting;
      return AdaptiveForm(
        title: 'Liên kết tài khoản Google',
        saving: busy,
        actions: [
          FilledButton(
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Đang liên kết…' : 'Liên kết và đăng nhập'),
          ),
        ],
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state is GoogleLinkRequired) ...[
                Text(
                  state.email,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (state.error != null) ...[
                  InlineNotice(state.error!, error: true),
                  const SizedBox(height: 16),
                ],
              ],
              const Text(
                'Nhập tài khoản HRM đã được cấp để xác nhận liên kết lần đầu. Những lần sau bạn chỉ cần chọn tài khoản Google này.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phone,
                enabled: !busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại HRM',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) =>
                    !RegExp(r'^[0-9+() -]{8,15}$').hasMatch(v?.trim() ?? '')
                    ? 'Nhập số điện thoại hợp lệ'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _password,
                enabled: !busy,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu HRM',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: busy
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Vui lòng nhập mật khẩu HRM'
                    : null,
              ),
            ],
          ),
        ),
      );
    },
  );
}
