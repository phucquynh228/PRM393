import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/features/auth/data/repositories/password_support_repository.dart';
import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

class PasswordSupportDecisionDialog extends StatefulWidget {
  final PasswordSupportRepository repository;
  final Map<String, dynamic> request;
  final bool resolve;
  const PasswordSupportDecisionDialog({
    super.key,
    required this.repository,
    required this.request,
    required this.resolve,
  });

  @override
  State<PasswordSupportDecisionDialog> createState() =>
      _PasswordSupportDecisionDialogState();
}

class _PasswordSupportDecisionDialogState
    extends State<PasswordSupportDecisionDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _note = TextEditingController();
  bool _verified = false, _saving = false, _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (widget.resolve && !_verified) {
      setState(
        () => _error =
            'Cần xác minh trực tiếp danh tính trước khi đặt lại mật khẩu.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.decide(
        widget.request['id'] as int,
        resolve: widget.resolve,
        identityVerified: _verified,
        password: _password.text,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = readableApiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: widget.resolve ? 'Đặt lại mật khẩu' : 'Từ chối yêu cầu',
    saving: _saving,
    actions: [
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(
          _saving
              ? 'Đang xử lý…'
              : widget.resolve
              ? 'Xác nhận đặt lại'
              : 'Xác nhận từ chối',
        ),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.request['name']} · ${widget.request['phone']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            InlineNotice(_error!, error: true),
            const SizedBox(height: 16),
          ],
          if (widget.resolve) ...[
            const InlineNotice(
              'Đối chiếu danh tính trực tiếp với hồ sơ nhân sự trước khi xử lý. Họ tên, SĐT và ghi chú do người gửi nhập chỉ là thông tin tham khảo. Sau khi đặt lại, trao mật khẩu trực tiếp cho đúng người đã xác minh. Các phiên đăng nhập cũ sẽ hết hiệu lực.',
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Tôi đã xác minh trực tiếp danh tính nhân viên',
              ),
              value: _verified,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _verified = value ?? false),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              enabled: !_saving,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty || value.length < 8
                  ? 'Mật khẩu cần ít nhất 8 ký tự'
                  : utf8.encode(value).length > 72
                  ? 'Mật khẩu tối đa 72 byte UTF-8'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              enabled: !_saving,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
              ),
              validator: (value) => value != _password.text
                  ? 'Mật khẩu xác nhận chưa khớp'
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _note,
            enabled: !_saving,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: widget.resolve
                  ? 'Ghi chú xử lý (không bắt buộc)'
                  : 'Lý do từ chối',
            ),
            validator: (value) =>
                !widget.resolve && (value == null || value.trim().isEmpty)
                ? 'Vui lòng nhập lý do từ chối'
                : null,
          ),
        ],
      ),
    ),
  );
}
