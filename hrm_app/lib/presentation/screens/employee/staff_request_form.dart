import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../data/repositories/staff_repository.dart';
import '../../widgets/adaptive_form.dart';
import '../../widgets/content_widgets.dart';
import '../branch/branch_helpers.dart';
import 'staff_helpers.dart';

class StaffRequestForm extends StatefulWidget {
  final StaffRepository repository;
  final String initialType;
  final int? scheduleId;
  const StaffRequestForm({
    super.key,
    required this.repository,
    this.initialType = 'LEAVE',
    this.scheduleId,
  });
  static Future<bool?> show(
    BuildContext context,
    StaffRepository repository, {
    String type = 'LEAVE',
    int? scheduleId,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StaffRequestForm(
      repository: repository,
      initialType: type,
      scheduleId: scheduleId,
    ),
  );
  @override
  State<StaffRequestForm> createState() => _StaffRequestFormState();
}

class _StaffRequestFormState extends State<StaffRequestForm> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late String _type = widget.initialType;
  DateTime _start = DateUtils.dateOnly(DateTime.now());
  late DateTime _end = _start;
  DateTime? _checkIn, _checkOut;
  int? _source, _target;
  List<StaffItem> _mine = [], _peers = [];
  bool _loading = false, _saving = false;
  String? _error, _optionsError;
  bool get _leave => _type == 'LEAVE' || _type == 'UNPAID_LEAVE';

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _optionsError = null;
    });
    try {
      final data = await widget.repository.options();
      if (!mounted) return;
      setState(() {
        _mine = staffItems(data['mine']);
        _peers = staffItems(data['peers']);
      });
      final initial = _choices
          .where((s) => s['id'] == widget.scheduleId)
          .firstOrNull;
      if (initial != null) _chooseSource(initial['id'] as int);
    } catch (e) {
      if (mounted) setState(() => _optionsError = readableApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<StaffItem> get _choices => _mine.where((s) {
    final start = DateTime.tryParse('${s['startsAt']}');
    if (start == null || s['status'] == 'ON_LEAVE') return false;
    return _type == 'SHIFT_SWAP'
        ? s['status'] == 'PENDING' && start.isAfter(DateTime.now())
        : !DateUtils.dateOnly(start)
              .isAfter(DateUtils.dateOnly(DateTime.now()));
  }).toList();

  void _chooseSource(int? id) {
    final item = _mine.where((s) => s['id'] == id).firstOrNull;
    setState(() {
      _source = id;
      _checkIn = DateTime.tryParse('${item?['startsAt']}');
      _checkOut = DateTime.tryParse('${item?['endsAt']}');
    });
  }

  Future<void> _pickDay(bool start) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final day = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: start ? now : _start,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || day == null) return;
    setState(() {
      if (start) {
        _start = day;
        if (_end.isBefore(day)) _end = day;
      } else {
        _end = day;
      }
    });
  }

  Future<void> _pickTime(bool checkIn) async {
    final source = _mine.where((s) => s['id'] == _source).firstOrNull;
    if (source == null) return;
    final first = DateTime.parse('${source['date']}');
    final now = DateTime.now();
    final initial = (checkIn ? _checkIn : _checkOut) ?? first;
    final day = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? DateUtils.dateOnly(now) : initial,
      firstDate: first,
      lastDate: DateUtils.dateOnly(now),
    );
    if (!mounted || day == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    final value = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (checkIn) {
        _checkIn = value;
      } else {
        _checkOut = value;
      }
    });
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_leave &&
        (_end.isBefore(_start) || _end.difference(_start).inDays > 30)) {
      setState(() => _error = 'Mỗi đơn nghỉ tối đa 31 ngày.');
      return;
    }
    if (!_leave && _source == null) {
      setState(() => _error = 'Vui lòng chọn ca làm.');
      return;
    }
    if (_type == 'SHIFT_SWAP' && _target == null) {
      setState(() => _error = 'Vui lòng chọn ca muốn nhận.');
      return;
    }
    if (_type == 'ATTENDANCE_CORRECTION' &&
        (_checkIn == null ||
            _checkOut == null ||
            !_checkOut!.isAfter(_checkIn!) ||
            _checkOut!.isAfter(DateTime.now()))) {
      setState(() => _error = 'Giờ ra phải sau giờ vào và không ở tương lai.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.send(
        'POST',
        '/requests',
        data: {
          'type': _type,
          'startDate': StaffRepository.date(_start),
          'endDate': StaffRepository.date(_end),
          'reason': _reason.text.trim(),
          if (!_leave) 'sourceScheduleId': _source,
          if (_type == 'SHIFT_SWAP') 'targetScheduleId': _target,
          if (_type == 'ATTENDANCE_CORRECTION') ...{
            'requestedCheckIn': _checkIn!.toIso8601String(),
            'requestedCheckOut': _checkOut!.toIso8601String(),
          },
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
    title: 'Tạo yêu cầu',
    saving: _saving,
    actions: [
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Đang gửi…' : 'Gửi tới quản lý'),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Theo dõi kết quả và lý do phản hồi ở mục Yêu cầu.'),
          const SizedBox(height: 20),
          if (_error != null) ...[
            InlineNotice(_error!, error: true),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Loại yêu cầu'),
            items: staffRequestTypes.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() {
                    _type = v!;
                    _source = null;
                    _target = null;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 16),
          if (_leave) ...[
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickDay(true),
              icon: const Icon(Icons.event),
              label: Text('Từ ngày ${BranchHelpers.prettyDate(_start)}'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickDay(false),
              icon: const Icon(Icons.event),
              label: Text('Đến ngày ${BranchHelpers.prettyDate(_end)}'),
            ),
          ] else ...[
            if (_loading) const LinearProgressIndicator(),
            if (_optionsError != null) ...[
              InlineNotice(_optionsError!, error: true),
              TextButton(
                onPressed: _loadOptions,
                child: const Text('Tải lại danh sách ca'),
              ),
            ],
            DropdownButtonFormField<int>(
              key: ValueKey('source-$_type-$_source'),
              initialValue: _source,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ca làm của bạn'),
              items: _choices
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as int,
                      child: Text(
                        shiftLabel(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving || _loading ? null : _chooseSource,
              validator: (v) =>
                  v == null ? 'Chọn ca làm cần gửi yêu cầu' : null,
            ),
            if (!_loading && _choices.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: InlineNotice(
                  'Chưa có ca làm hợp lệ. Đổi ca áp dụng cho ca chưa bắt đầu; sửa công áp dụng trong 30 ngày gần đây.',
                ),
              ),
            if (_type == 'SHIFT_SWAP') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: ValueKey('target-$_target'),
                initialValue: _target,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ca muốn nhận (cùng chi nhánh)',
                ),
                items: _peers
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['id'] as int,
                        child: Text(
                          shiftLabel(s, person: true),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _saving || _loading
                    ? null
                    : (v) => setState(() => _target = v),
                validator: (v) => v == null ? 'Chọn ca muốn nhận' : null,
              ),
              const SizedBox(height: 12),
              const InlineNotice(
                'Quản lý sẽ kiểm tra trùng lịch và chuyển hai ca cho nhau khi duyệt.',
              ),
            ],
            if (_type == 'ATTENDANCE_CORRECTION') ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _saving || _source == null
                    ? null
                    : () => _pickTime(true),
                child: Text('Giờ vào đề xuất: ${stamp(_checkIn)}'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _saving || _source == null
                    ? null
                    : () => _pickTime(false),
                child: Text('Giờ ra đề xuất: ${stamp(_checkOut)}'),
              ),
              const SizedBox(height: 12),
              const InlineNotice(
                'Áp dụng khi quên chấm công hoặc ghi sai giờ. Công chỉ được cập nhật sau khi quản lý duyệt.',
              ),
            ],
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: _reason,
            enabled: !_saving,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Lý do',
              alignLabelWithHint: true,
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Vui lòng nhập lý do' : null,
          ),
        ],
      ),
    ),
  );
}
