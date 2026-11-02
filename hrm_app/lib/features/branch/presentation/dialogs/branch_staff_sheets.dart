import 'package:flutter/material.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/fixed_roster_editor.dart';

import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';

class BranchStaffDetailsSheet {
  static void show(
    BuildContext context, {
    required Map<String, dynamic> staff,
    required String branchName,
    required VoidCallback onViewShifts,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              staff['name'] ?? 'Nhân viên',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            BranchHelpers.detailRow(
              Icons.phone_outlined,
              'Điện thoại',
              staff['phone'] ?? '—',
            ),
            BranchHelpers.detailRow(
              Icons.store_outlined,
              'Chi nhánh',
              branchName,
            ),
            BranchHelpers.detailRow(
              Icons.phonelink_outlined,
              'Thiết bị',
              staff['deviceId'] == null ? 'Chưa liên kết' : 'Đã liên kết',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onViewShifts();
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Mở lịch phân ca'),
            ),
            const SizedBox(height: 20),
            FixedRosterSummary(entries: staff['fixedRoster']),
          ],
        ),
      ),
    );
  }
}

class BranchStaffFormSheet {
  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? staff,
    required Future<void> Function(String method, String path, {Object? data})
    onSend,
    required Future<void> Function() onReload,
    required void Function(String, {bool isError}) showMessage,
    required String Function(dynamic) cleanError,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StaffForm(
      staff: staff,
      onSend: onSend,
      onReload: onReload,
      showMessage: showMessage,
      cleanError: cleanError,
    ),
  );
}

class _StaffForm extends StatefulWidget {
  final Map<String, dynamic>? staff;
  final Future<void> Function(String method, String path, {Object? data})
  onSend;
  final Future<void> Function() onReload;
  final void Function(String, {bool isError}) showMessage;
  final String Function(dynamic) cleanError;
  const _StaffForm({
    this.staff,
    required this.onSend,
    required this.onReload,
    required this.showMessage,
    required this.cleanError,
  });
  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.staff?['name'] ?? '');
  late final _phone = TextEditingController(text: widget.staff?['phone'] ?? '');
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;
  late Set<String> _fixedRoster = rosterSelection(widget.staff?['fixedRoster']);
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
      await widget.onSend(
        widget.staff == null ? 'POST' : 'PUT',
        widget.staff == null
            ? '/manager/staff'
            : '/manager/staff/${widget.staff!['id']}',
        data: {
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          if (_password.text.isNotEmpty) 'password': _password.text,
          'fixedRoster': rosterEntries(_fixedRoster),
        },
      );
      if (mounted) Navigator.pop(context);
      await widget.onReload();
      widget.showMessage('Đã lưu thông tin nhân viên.');
    } catch (e) {
      if (mounted) setState(() => _error = widget.cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: widget.staff == null ? 'Thêm nhân viên' : 'Chỉnh sửa nhân viên',
    saving: _saving,
    actions: [
      OutlinedButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Đang lưu…' : 'Lưu nhân viên'),
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
            decoration: InputDecoration(
              labelText: widget.staff == null
                  ? 'Mật khẩu'
                  : 'Mật khẩu mới (không bắt buộc)',
            ),
            validator: (s) =>
                (widget.staff == null || (s?.isNotEmpty ?? false)) &&
                    (s?.length ?? 0) < 6
                ? 'Mật khẩu tối thiểu 6 ký tự'
                : null,
          ),
          const SizedBox(height: 24),
          FixedRosterEditor(
            selected: _fixedRoster,
            enabled: !_saving,
            onChanged: (selected) => setState(() => _fixedRoster = selected),
          ),
        ],
      ),
    ),
  );
}
