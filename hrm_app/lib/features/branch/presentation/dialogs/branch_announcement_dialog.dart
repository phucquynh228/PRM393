import 'package:flutter/material.dart';

import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

class BranchAnnouncementDialog extends StatefulWidget {
  final Future<void> Function(String, String, {Object? data}) send;
  const BranchAnnouncementDialog({super.key, required this.send});
  static Future<void> show(
    BuildContext context,
    Future<void> Function(String, String, {Object? data}) send,
    void Function(String, {bool isError}) message,
  ) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BranchAnnouncementDialog(send: send),
    );
    if (done == true) message('Đã gửi thông báo tới nhân viên chi nhánh.');
  }

  @override
  State<BranchAnnouncementDialog> createState() =>
      _BranchAnnouncementDialogState();
}

class _BranchAnnouncementDialogState extends State<BranchAnnouncementDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(), _body = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.send(
        'POST',
        '/manager/announcements',
        data: {'title': _title.text.trim(), 'message': _body.text.trim()},
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
    title: 'Thông báo cho chi nhánh',
    saving: _saving,
    actions: [
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Đang gửi…' : 'Gửi thông báo'),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tất cả nhân viên thuộc chi nhánh sẽ nhận được thông báo trong ứng dụng.',
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            InlineNotice(_error!, error: true),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _title,
            enabled: !_saving,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Tiêu đề'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập tiêu đề thông báo' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _body,
            enabled: !_saving,
            maxLength: 2000,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Nội dung',
              alignLabelWithHint: true,
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Nhập nội dung thông báo'
                : null,
          ),
        ],
      ),
    ),
  );
}
