import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/features/admin/data/admin_profile_repository.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

enum AdminProfileSection { personal, security, settings }

class AdminProfileSectionScreen extends StatefulWidget {
  final AdminProfileSection section;
  final AdminProfileRepository repository;
  final Future<void> Function() onProfileChanged;
  final Future<void> Function() onPasswordChanged;
  final VoidCallback onShiftTemplates;
  final VoidCallback onBranches;
  const AdminProfileSectionScreen({
    super.key,
    required this.section,
    required this.repository,
    required this.onProfileChanged,
    required this.onPasswordChanged,
    required this.onShiftTemplates,
    required this.onBranches,
  });
  @override
  State<AdminProfileSectionScreen> createState() =>
      _AdminProfileSectionScreenState();
}

class _AdminProfileSectionScreenState extends State<AdminProfileSectionScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _address = TextEditingController();
  final _old = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController(),
      _reminder = TextEditingController();
  Map<String, dynamic> _data = {};
  String? _error;
  bool _loading = true, _saving = false, _obscure = true;
  bool get _personal => widget.section == AdminProfileSection.personal;
  bool get _security => widget.section == AdminProfileSection.security;
  String get _title => _personal
      ? 'Thông tin cá nhân'
      : _security
      ? 'Tài khoản và bảo mật'
      : 'Cấu hình hệ thống';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _address,
      _old,
      _password,
      _confirm,
      _reminder,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.call(
        widget.section == AdminProfileSection.settings ? 'settings' : 'profile',
      );
      if (!mounted) return;
      _data = data;
      _name.text = '${data['name'] ?? ''}';
      _email.text = '${data['email'] ?? ''}';
      _address.text = '${data['address'] ?? ''}';
      _reminder.text = '${data['reminderMinutes'] ?? 10}';
    } catch (e) {
      if (mounted) _error = readableApiError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.call(
        _personal
            ? 'profile'
            : _security
            ? 'profile/password'
            : 'settings',
        data: _personal
            ? {
                'name': _name.text.trim(),
                'email': _email.text.trim(),
                'address': _address.text.trim(),
              }
            : _security
            ? {'currentPassword': _old.text, 'newPassword': _password.text}
            : {'reminderMinutes': int.parse(_reminder.text)},
      );
      if (_security) {
        await widget.onPasswordChanged();
        return;
      }
      if (_personal) await widget.onProfileChanged();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = readableApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLength = 255,
    bool password = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      obscureText: password && _obscure,
      maxLength: password ? null : maxLength,
      autocorrect: !password,
      enableSuggestions: !password,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value ?? '';
        if (required && text.trim().isEmpty) return 'Vui lòng nhập $label';
        if (controller == _email &&
            text.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text.trim())) {
          return 'Email không hợp lệ';
        }
        if (controller == _password &&
            (text.length < 8 || utf8.encode(text).length > 72)) {
          return 'Mật khẩu cần 8 ký tự trở lên, tối đa 72 byte UTF-8';
        }
        if (controller == _confirm && text != _password.text) {
          return 'Mật khẩu xác nhận chưa khớp';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_error != null) ...[
                        InlineNotice(_error!, error: true),
                        const SizedBox(height: 16),
                      ],
                      if (_data.isEmpty)
                        TextButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        )
                      else
                        SurfaceCard(
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_personal) ...[
                                  Text(
                                    'Mã tài khoản: ${_data['id']} · ${_data['phone']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 20),
                                  _field(
                                    _name,
                                    'Họ và tên',
                                    required: true,
                                    maxLength: 100,
                                  ),
                                  _field(_email, 'Email', maxLength: 150),
                                  _field(_address, 'Địa chỉ'),
                                ] else if (_security) ...[
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.phone_outlined),
                                    title: const Text(
                                      'Số điện thoại đăng nhập',
                                    ),
                                    subtitle: Text('${_data['phone']}'),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.phonelink_lock_outlined,
                                    ),
                                    title: const Text('Thiết bị đăng nhập'),
                                    subtitle: Text(
                                      _data['deviceLinked'] == true
                                          ? 'Đã liên kết thiết bị'
                                          : 'Chưa liên kết thiết bị',
                                    ),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.account_circle_outlined,
                                    ),
                                    title: const Text('Tài khoản Google'),
                                    subtitle: Text(
                                      _data['googleLinked'] == true
                                          ? 'Đã liên kết'
                                          : 'Chưa liên kết',
                                    ),
                                  ),
                                  const Divider(height: 32),
                                  const Text('Đổi mật khẩu'),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Bạn có thể tự đổi mật khẩu bằng mật khẩu hiện tại.',
                                  ),
                                  const SizedBox(height: 16),
                                  _field(
                                    _old,
                                    'Mật khẩu hiện tại',
                                    required: true,
                                    password: true,
                                  ),
                                  _field(
                                    _password,
                                    'Mật khẩu mới',
                                    required: true,
                                    password: true,
                                  ),
                                  _field(
                                    _confirm,
                                    'Nhập lại mật khẩu mới',
                                    required: true,
                                    password: true,
                                  ),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Hiện mật khẩu'),
                                    value: !_obscure,
                                    onChanged: _saving
                                        ? null
                                        : (value) =>
                                              setState(() => _obscure = !value),
                                  ),
                                  const InlineNotice(
                                    'Sau khi đổi mật khẩu, các phiên đăng nhập cũ sẽ hết hiệu lực. Bạn sẽ cần đăng nhập lại.',
                                  ),
                                  const SizedBox(height: 16),
                                ] else ...[
                                  Text(
                                    'Thông báo và vận hành',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _reminder,
                                    enabled: !_saving,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Nhắc trước ca (phút)',
                                      helperText: 'Từ 1 đến 120 phút · áp dụng cho thông báo trong app',
                                      helperMaxLines: 2,
                                    ),
                                    validator: (value) {
                                      final n = int.tryParse(value ?? '');
                                      return n == null || n < 1 || n > 120
                                          ? 'Nhập số nguyên từ 1 đến 120'
                                          : null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _data['timezone'] == 'Asia/Ho_Chi_Minh'
                                        ? 'Múi giờ: Việt Nam (UTC+7)'
                                        : 'Múi giờ: ${_data['timezone']}',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Giới hạn check-out: ${_data['maxCheckoutHours']} giờ từ lúc check-in',
                                  ),
                                  const Divider(height: 32),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.schedule_outlined,
                                    ),
                                    title: const Text('Mẫu ca làm việc'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: _saving
                                        ? null
                                        : widget.onShiftTemplates,
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.storefront_outlined,
                                    ),
                                    title: const Text('Cấu hình chi nhánh'),
                                    subtitle: const Text(
                                      'Vị trí GPS, bán kính chấm công, định biên',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: _saving ? null : widget.onBranches,
                                  ),
                                ],
                                FilledButton(
                                  onPressed: _saving ? null : _save,
                                  child: Text(
                                    _saving
                                        ? 'Đang lưu…'
                                        : _security
                                        ? 'Đổi mật khẩu'
                                        : 'Lưu thay đổi',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
