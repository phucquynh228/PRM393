import 'package:flutter/material.dart';

import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/features/staff/presentation/dialogs/request_form.dart';
import 'package:hrm_app/features/staff/presentation/helpers/staff_helpers.dart';

class BranchRequestDecisionDialog {
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> request,
    required bool approved,
    required Future<void> Function(String? managerNote) onConfirm,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _Decision(request: request, approved: approved, onConfirm: onConfirm),
  );
}

class _Decision extends StatefulWidget {
  final Map<String, dynamic> request;
  final bool approved;
  final Future<void> Function(String?) onConfirm;
  const _Decision({
    required this.request,
    required this.approved,
    required this.onConfirm,
  });
  @override
  State<_Decision> createState() => _DecisionState();
}

class _DecisionState extends State<_Decision> {
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!widget.approved && _note.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onConfirm(
        _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = requestError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.approved ? 'Duyệt yêu cầu?' : 'Từ chối yêu cầu?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.request['userName']} · ${requestType(widget.request['type'])}',
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              InlineNotice(_error!, error: true),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _note,
              enabled: !_saving,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú cho nhân viên',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Khi được duyệt, lịch làm hoặc chấm công liên quan sẽ được cập nhật và nhân viên nhận thông báo.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang xử lý…' : 'Xác nhận'),
        ),
      ],
    ),
  );
}
