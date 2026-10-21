import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../data/repositories/staff_repository.dart';
import '../../widgets/adaptive_form.dart';
import '../../widgets/content_widgets.dart';

class StaffProfileForm extends StatefulWidget {
  final StaffRepository repository;
  final StaffItem profile;
  final bool password;
  const StaffProfileForm({
    super.key,
    required this.repository,
    required this.profile,
    this.password = false,
  });
  static Future<bool?> show(
    BuildContext context,
    StaffRepository repository,
    StaffItem profile, {
    bool password = false,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StaffProfileForm(
      repository: repository,
      profile: profile,
      password: password,
    ),
  );
  @override
  State<StaffProfileForm> createState() => _StaffProfileFormState();
}

class _StaffProfileFormState extends State<StaffProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.profile['name']?.toString(),
  );
  late final _email = TextEditingController(
    text: widget.profile['email']?.toString(),
  );
  late final _address = TextEditingController(
    text: widget.profile['address']?.toString(),
  );
  late final _contact = TextEditingController(
    text: widget.profile['emergencyContact']?.toString(),
  );
  final _old = TextEditingController(),
      _new = TextEditingController(),
      _confirm = TextEditingController();
  bool _saving = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _email, _address, _contact, _old, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.send(
        'PUT',
        widget.password ? '/staff/password' : '/staff/profile',
        data: widget.password
            ? {'currentPassword': _old.text, 'newPassword': _new.text}
            : {
                'name': _name.text.trim(),
                'email': _email.text.trim(),
                'address': _address.text.trim(),
                'emergencyContact': _contact.text.trim(),
              },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = readableApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: widget.password ? 'Đổi mật khẩu' : 'Cập nhật hồ sơ',
    saving: _saving,
    actions: [
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Đang lưu…' : 'Lưu thay đổi'),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            InlineNotice(_error!, error: true),
            const SizedBox(height: 16),
          ],
          if (widget.password) ...[
            for (final entry in [
              (_old, 'Mật khẩu hiện tại'),
              (_new, 'Mật khẩu mới'),
              (_confirm, 'Nhập lại mật khẩu mới'),
            ]) ...[
              TextFormField(
                controller: entry.$1,
                enabled: !_saving,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: entry.$2),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Vui lòng nhập ${entry.$2.toLowerCase()}';
                  }
                  if (entry.$1 == _new &&
                      (v.length < 6 || utf8.encode(v).length > 72)) {
                    return 'Mật khẩu từ 6 ký tự, tối đa 72 byte';
                  }
                  if (entry.$1 == _confirm && v != _new.text) {
                    return 'Mật khẩu nhập lại chưa khớp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hiện mật khẩu'),
              value: !_obscure,
              onChanged: _saving ? null : (v) => setState(() => _obscure = !v!),
            ),
          ] else ...[
            const InlineNotice(
              'Số điện thoại đăng nhập, chức vụ và chi nhánh do quản lý cập nhật.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              enabled: !_saving,
              maxLength: 150,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (không bắt buộc)',
              ),
              validator: (v) =>
                  v != null &&
                      v.isNotEmpty &&
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                  ? 'Địa chỉ email chưa hợp lệ'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contact,
              enabled: !_saving,
              maxLength: 20,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số liên hệ khẩn cấp (không bắt buộc)',
              ),
              validator: (v) =>
                  v != null &&
                      v.isNotEmpty &&
                      !RegExp(r'^[0-9+ ()-]{9,20}$').hasMatch(v.trim())
                  ? 'Số liên hệ chưa hợp lệ'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              enabled: !_saving,
              maxLength: 255,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ (không bắt buộc)',
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
