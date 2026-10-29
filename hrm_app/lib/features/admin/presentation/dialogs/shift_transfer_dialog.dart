import 'package:flutter/material.dart';
import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';
import 'package:hrm_app/features/staff/presentation/helpers/staff_helpers.dart';
import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

class ShiftTransferDialog extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final List<Map<String, dynamic>> stores;
  final Future<void> Function(int targetStoreId) onSave;
  const ShiftTransferDialog({
    super.key,
    required this.schedule,
    required this.stores,
    required this.onSave,
  });

  @override
  State<ShiftTransferDialog> createState() => _ShiftTransferDialogState();
}

class _ShiftTransferDialogState extends State<ShiftTransferDialog> {
  int? _target;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || _target == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_target!);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = readableApiError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: 'Điều chuyển ca làm',
    saving: _saving,
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving || _target == null ? null : _save,
        child: Text(_saving ? 'Đang chuyển…' : 'Chuyển ca'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.schedule['userName']}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.schedule['shiftName']} · ${BranchHelpers.formatIsoDate(widget.schedule['date'])}',
        ),
        Text(
          '${shortTime(widget.schedule['startTime'])} – ${shortTime(widget.schedule['endTime'])}',
        ),
        const SizedBox(height: 12),
        Text('Chi nhánh hiện tại: ${widget.schedule['storeName']}'),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          initialValue: _target,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Chi nhánh nhận ca'),
          items: widget.stores
              .map(
                (s) => DropdownMenuItem<int>(
                  value: (s['id'] as num).toInt(),
                  child: Text('${s['name']}', overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) => setState(() => _target = value),
        ),
        const SizedBox(height: 20),
        InlineNotice(
          widget.schedule['published'] == true
              ? 'Ca vẫn được công bố. Nhân viên sẽ nhận thông báo chi nhánh làm việc mới.'
              : 'Ca vẫn là bản nháp. Manager chi nhánh nhận cần công bố để nhân viên xem được.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Chỉ chuyển ca đang chọn; giữ nguyên ngày, giờ và chi nhánh chính của nhân viên.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          InlineNotice(_error!, error: true),
        ],
      ],
    ),
  );
}
