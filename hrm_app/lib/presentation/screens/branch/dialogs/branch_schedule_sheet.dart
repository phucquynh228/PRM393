import 'package:flutter/material.dart';

import '../../../widgets/adaptive_form.dart';
import '../../../widgets/content_widgets.dart';
import '../branch_helpers.dart';

class BranchScheduleSheet {
  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? schedule,
    required List<Map<String, dynamic>> staff,
    required List<Map<String, dynamic>> shifts,
    required List<Map<String, dynamic>> schedules,
    required DateTime initialDate,
    required Future<void> Function(String method, String path, {Object? data})
    onSend,
    required Future<void> Function() onReload,
    required void Function(String, {bool isError}) showMessage,
    required String Function(dynamic) cleanError,
    required Future<void> Function({
      required DateTime initial,
      DateTime? firstDate,
      DateTime? lastDate,
      required ValueChanged<DateTime> onPicked,
    })
    onPickDate,
  }) async {
    if (staff.isEmpty || shifts.isEmpty) {
      showMessage('Cần có nhân viên và mẫu ca làm trước.', isError: true);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScheduleForm(
        schedule: schedule,
        staff: staff,
        shifts: shifts,
        schedules: schedules,
        initialDate: initialDate,
        onSend: onSend,
        onReload: onReload,
        showMessage: showMessage,
        cleanError: cleanError,
      ),
    );
  }

  static Future<void> confirmDelete(
    BuildContext context, {
    required Map<String, dynamic> schedule,
    required Future<void> Function() onConfirm,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ca làm?'),
        content: Text(
          'Xóa ${schedule['shiftName']} của ${schedule['userName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa ca'),
          ),
        ],
      ),
    );
    if (yes == true) await onConfirm();
  }
}

class _ScheduleForm extends StatefulWidget {
  final Map<String, dynamic>? schedule;
  final List<Map<String, dynamic>> staff, shifts, schedules;
  final DateTime initialDate;
  final Future<void> Function(String method, String path, {Object? data})
  onSend;
  final Future<void> Function() onReload;
  final void Function(String, {bool isError}) showMessage;
  final String Function(dynamic) cleanError;
  const _ScheduleForm({
    this.schedule,
    required this.staff,
    required this.shifts,
    required this.schedules,
    required this.initialDate,
    required this.onSend,
    required this.onReload,
    required this.showMessage,
    required this.cleanError,
  });
  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final _form = GlobalKey<FormState>();
  late int _staff =
      widget.schedule?['userId'] as int? ?? widget.staff.first['id'] as int;
  late int _shift =
      widget.schedule?['shiftId'] as int? ?? widget.shifts.first['id'] as int;
  late DateTime _day =
      DateTime.tryParse(widget.schedule?['date']?.toString() ?? '') ??
      widget.initialDate;
  bool _saving = false;
  String? _error;
  Future<void> _save(bool published) async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_day.isBefore(DateUtils.dateOnly(DateTime.now()))) {
      setState(() => _error = 'Chọn ngày từ hôm nay trở đi.');
      return;
    }
    if (widget.schedules.any(
      (s) =>
          s['userId'] == _staff &&
          s['shiftId'] == _shift &&
          s['date'] == BranchHelpers.dateToYmd(_day) &&
          s['id'] != widget.schedule?['id'],
    )) {
      setState(
        () => _error = 'Nhân viên đã được phân ca này trong ngày đã chọn.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSend(
        widget.schedule == null ? 'POST' : 'PUT',
        widget.schedule == null
            ? '/manager/schedules'
            : '/manager/schedules/${widget.schedule!['id']}',
        data: {
          'userId': _staff,
          'shiftId': _shift,
          'date': BranchHelpers.dateToYmd(_day),
          'published': published,
        },
      );
      if (mounted) Navigator.pop(context);
      await widget.onReload();
      widget.showMessage(
        published ? 'Đã lưu và công bố ca làm.' : 'Đã lưu bản nháp.',
      );
    } catch (e) {
      if (mounted) setState(() => _error = widget.cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: widget.schedule == null ? 'Phân ca mới' : 'Chỉnh sửa ca',
    saving: _saving,
    actions: [
      OutlinedButton(
        onPressed: _saving ? null : () => _save(false),
        child: const Text('Lưu nháp'),
      ),
      FilledButton(
        onPressed: _saving ? null : () => _save(true),
        child: Text(_saving ? 'Đang lưu…' : 'Lưu và công bố'),
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
          DropdownButtonFormField<int>(
            initialValue: _staff,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nhân viên'),
            items: widget.staff
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
            onChanged: _saving
                ? null
                : (value) => setState(() => _staff = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _shift,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ca làm'),
            items: widget.shifts
                .map(
                  (s) => DropdownMenuItem<int>(
                    value: s['id'],
                    child: Text(
                      '${s['name']} · ${s['startTime']} – ${s['endTime']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _shift = value!),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final now = DateUtils.dateOnly(DateTime.now());
                    final day = await showDatePicker(
                      context: context,
                      initialDate: _day.isBefore(now) ? now : _day,
                      firstDate: now,
                      lastDate: DateTime(2100),
                    );
                    if (day != null && mounted) setState(() => _day = day);
                  },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(BranchHelpers.prettyDate(_day)),
          ),
          const SizedBox(height: 20),
          const InlineNotice(
            'Ca nháp chỉ hiển thị với quản lý. Nhân viên xem được ca sau khi bạn công bố.',
          ),
        ],
      ),
    ),
  );
}
