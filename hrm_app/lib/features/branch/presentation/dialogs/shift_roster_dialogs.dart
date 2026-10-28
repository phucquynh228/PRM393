import 'package:flutter/material.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/fixed_roster_editor.dart';
import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

class ShiftStaffPicker extends StatefulWidget {
  final String slot;
  final DateTime date;
  final List<Map<String, dynamic>> staff, assignments;
  final Future<void> Function(List<int>) onSave;
  final String Function(dynamic) cleanError;
  const ShiftStaffPicker({
    super.key,
    required this.slot,
    required this.date,
    required this.staff,
    required this.assignments,
    required this.onSave,
    required this.cleanError,
  });
  @override
  State<ShiftStaffPicker> createState() => _ShiftStaffPickerState();
}

class _ShiftStaffPickerState extends State<ShiftStaffPicker> {
  final Set<int> _selected = {};
  String _query = '';
  bool _saving = false;
  String? _error;
  Set<int> get _existing => widget.assignments
      .where((s) => s['status'] != 'CANCELLED' && s['status'] != 'ON_LEAVE')
      .map((s) => (s['userId'] as num).toInt())
      .toSet();
  Future<void> _save() async {
    if (_saving || _selected.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_selected.toList()..sort());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.cleanError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: 'Thêm nhân sự · ${rosterSlots[widget.slot]}',
    saving: _saving,
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving || _selected.isEmpty ? null : _save,
        child: Text(
          _saving ? 'Đang thêm…' : 'Thêm ${_selected.length} nhân sự',
        ),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ngày ${widget.date.day}/${widget.date.month}/${widget.date.year} · Lưu thành bản nháp',
        ),
        const SizedBox(height: 12),
        TextField(
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Tìm nhân viên',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          InlineNotice(_error!, error: true),
          const SizedBox(height: 12),
        ],
        if (widget.staff.isEmpty)
          const Text('Chưa có nhân viên đang làm việc trong chi nhánh.'),
        for (final person in widget.staff.where(
          (s) => '${s['name']} ${s['phone']}'.toLowerCase().contains(_query),
        ))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value:
                _existing.contains(person['id']) ||
                _selected.contains(person['id']),
            title: Text(person['name'] ?? 'Nhân viên'),
            subtitle: Text(
              _existing.contains(person['id'])
                  ? 'Đã có trong ca'
                  : rosterSelection(person['fixedRoster'])
                        .contains('${widget.date.weekday}:${widget.slot}')
                  ? 'Phù hợp ca mặc định · ${person['phone'] ?? ''}'
                  : '${person['phone'] ?? ''}',
            ),
            onChanged: _saving || _existing.contains(person['id'])
                ? null
                : (checked) => setState(() {
                    final id = (person['id'] as num).toInt();
                    if (checked == true) {
                      _selected.add(id);
                    } else {
                      _selected.remove(id);
                    }
                  }),
          ),
        const SizedBox(height: 12),
        const Text(
          'Có thể chọn nhiều người. Máy chủ kiểm tra lại nghỉ phép, trùng giờ và chi nhánh trước khi lưu toàn bộ lựa chọn.',
        ),
      ],
    ),
  );
}

class ShiftStaffingSettingsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> plans, shifts;
  final Future<void> Function(List<Map<String, dynamic>>) onSave;
  final String Function(dynamic) cleanError;
  const ShiftStaffingSettingsDialog({
    super.key,
    required this.plans,
    required this.shifts,
    required this.onSave,
    required this.cleanError,
  });
  @override
  State<ShiftStaffingSettingsDialog> createState() =>
      _ShiftStaffingSettingsDialogState();
}

class _ShiftStaffingSettingsDialogState
    extends State<ShiftStaffingSettingsDialog> {
  final _form = GlobalKey<FormState>();
  final Map<String, int> _ids = {};
  final Map<String, TextEditingController> _required = {};
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    for (final slot in rosterSlots.keys) {
      final plan = widget.plans.where((p) => p['slot'] == slot).firstOrNull;
      final id = (plan?['shiftId'] as num?)?.toInt() ?? 0;
      _ids[slot] = widget.shifts.any((s) => s['id'] == id) ? id : 0;
      _required[slot] = TextEditingController(
        text: '${plan?['requiredStaff'] ?? 0}',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _required.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final ids = _ids.values.where((id) => id != 0).toList();
    if (ids.toSet().length != ids.length) {
      setState(() => _error = 'Mỗi buổi cần dùng một mẫu ca khác nhau.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave([
        for (final slot in rosterSlots.keys)
          {
            'slot': slot,
            'shiftId': _ids[slot] == 0 ? null : _ids[slot],
            'requiredStaff': int.parse(_required[slot]!.text),
          },
      ]);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.cleanError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: 'Định mức nhân sự theo ca',
    saving: _saving,
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Đang lưu…' : 'Lưu định mức'),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chọn mẫu giờ và số người cần cho từng ca của chi nhánh. Số 0 nghĩa là chưa áp dụng cảnh báo định mức. Thay đổi chỉ áp dụng cho phân công mới.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InlineNotice(_error!, error: true),
          ],
          for (final slot in rosterSlots.keys) ...[
            const SizedBox(height: 24),
            Text(
              rosterSlots[slot]!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _ids[slot],
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Mẫu ca'),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Chưa chọn')),
                ...widget.shifts.map(
                  (s) => DropdownMenuItem(
                    value: (s['id'] as num).toInt(),
                    child: Text(
                      '${s['name']} · ${s['startTime']}–${s['endTime']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (id) => setState(() => _ids[slot] = id ?? 0),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _required[slot],
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số nhân viên yêu cầu',
              ),
              validator: (text) {
                final value = int.tryParse(text?.trim() ?? '');
                if (value == null || value < 0 || value > 200) {
                  return 'Nhập số nguyên từ 0 đến 200';
                }
                if (value > 0 && _ids[slot] == 0) {
                  return 'Chọn mẫu ca trước khi đặt định mức';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    ),
  );
}
