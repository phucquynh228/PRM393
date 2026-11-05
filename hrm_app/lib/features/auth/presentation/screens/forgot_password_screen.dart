import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/features/auth/data/repositories/password_support_repository.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final Dio dio;
  final String initialPhone;
  const ForgotPasswordScreen({
    super.key,
    required this.dio,
    this.initialPhone = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _name = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;
  String? _error, _acknowledgement;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await PasswordSupportRepository(widget.dio).submit(
        phone: _phone.text.trim(),
        name: _name.text.trim(),
        note: _note.text.trim(),
      );
      if (mounted) setState(() => _acknowledgement = message);
    } catch (error) {
      if (mounted) setState(() => _error = readableApiError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_acknowledgement != null) ...[
                  const Icon(Icons.support_agent, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    'Đã tiếp nhận thông tin',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  InlineNotice(_acknowledgement!),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Về đăng nhập'),
                  ),
                ] else ...[
                  Text(
                    'Yêu cầu Admin hỗ trợ',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Email và số điện thoại của tài khoản chưa được xác minh. Admin sẽ xác minh danh tính trực tiếp và hỗ trợ đặt lại mật khẩu. Nhập số điện thoại dùng để đăng nhập bên dưới.',
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    InlineNotice(_error!, error: true),
                    const SizedBox(height: 16),
                  ],
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _phone,
                          enabled: !_sending,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          maxLength: 15,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại đăng nhập',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) =>
                              RegExp(r'^[0-9]{10,15}$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Nhập số điện thoại gồm 10–15 chữ số',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _name,
                          enabled: !_sending,
                          textInputAction: TextInputAction.next,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Họ tên nhân viên',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vui lòng nhập họ tên'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _note,
                          enabled: !_sending,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú (không bắt buộc)',
                            hintText: 'Ví dụ: chi nhánh, mã nhân viên hoặc thời gian có thể gặp Admin',
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _sending ? null : _submit,
                          icon: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.support_agent),
                          label: Text(
                            _sending ? 'Đang gửi…' : 'Gửi yêu cầu hỗ trợ',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
