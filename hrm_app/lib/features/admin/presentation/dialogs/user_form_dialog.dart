import 'package:flutter/material.dart';

import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/features/staff/presentation/dialogs/request_form.dart';

class UserFormDialog extends StatefulWidget {
  final List<dynamic> stores;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(String, {bool isError}) showSnackBar;
  const UserFormDialog({
    super.key,
    required this.stores,
    required this.onSubmit,
    required this.showSnackBar,
  });
  static Future<void> show(
    BuildContext context, {
    required List<dynamic> stores,
    required Future<void> Function(Map<String, dynamic>) onSubmit,
    required void Function(String, {bool isError}) showSnackBar,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UserFormDialog(
      stores: stores,
      onSubmit: onSubmit,
      showSnackBar: showSnackBar,
    ),
  );
  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _password = TextEditingController();
  String _role = 'STAFF';
  int? _store;
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'role': _role,
        'storeId': _store,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = requestError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: 'Tạo tài khoản',
    saving: _saving,
    actions: [
      OutlinedButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Đang lưu…' : 'Tạo tài khoản'),
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
          TextFormField(
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: (s) =>
                s == null || s.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
            validator: (s) =>
                !RegExp(r'^[0-9+() -]{8,15}$').hasMatch(s?.trim() ?? '')
                ? 'Số điện thoại không hợp lệ'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            enabled: !_saving,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu'),
            validator: (s) =>
                (s?.length ?? 0) < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null,
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: const [
              DropdownMenuItem(value: 'STAFF', child: Text('Nhân viên')),
              DropdownMenuItem(value: 'MANAGER', child: Text('Quản lý')),
              DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _role = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _store,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Chi nhánh',
              helperText: 'Nhân viên cần được phân vào một chi nhánh.',
            ),
            items: widget.stores
                .where((s) => s['status'] == 'ACTIVE')
                .map(
                  (s) => DropdownMenuItem<int>(
                    value: s['id'],
                    child: Text(
                      s['name'] ?? '—',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _role == 'STAFF' && value == null
                ? 'Chọn chi nhánh cho nhân viên'
                : null,
            onChanged: _saving
                ? null
                : (value) => setState(() => _store = value),
          ),
        ],
      ),
    ),
  );
}
