import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/core/config/api_config.dart';
import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/empty_state_view.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/schedule_week_strip.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/schedule_roster_block.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/fixed_roster_editor.dart';
import 'package:hrm_app/features/admin/presentation/dialogs/shift_transfer_dialog.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';
import 'package:hrm_app/features/staff/presentation/helpers/staff_helpers.dart';

class AdminScheduleTab extends StatefulWidget {
  final Dio dio;
  final List<dynamic> stores;
  const AdminScheduleTab({super.key, required this.dio, required this.stores});
  @override
  State<AdminScheduleTab> createState() => _AdminScheduleTabState();
}

class _AdminScheduleTabState extends State<AdminScheduleTab> {
  List<Map<String, dynamic>> _shifts = [], _schedules = [], _settings = [];
  DateTime _anchor = DateUtils.dateOnly(DateTime.now());
  DateTime? _day = DateUtils.dateOnly(DateTime.now());
  String _period = 'Week', _filter = 'ALL';
  int? _store;
  bool _loading = true, _templates = false;
  String? _error;
  int _version = 0;
  DateTime get _from => _period == 'Day'
      ? _anchor
      : _period == 'Month'
      ? DateTime(_anchor.year, _anchor.month, 1)
      : _anchor.subtract(Duration(days: _anchor.weekday - 1));
  DateTime get _to => _period == 'Day'
      ? _anchor
      : _period == 'Month'
      ? DateTime(_anchor.year, _anchor.month + 1, 0)
      : _from.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<dynamic> _call(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final response = await widget.dio.request(
      '$globalBaseUrl/admin/$path',
      data: data,
      queryParameters: query,
      options: Options(method: method),
    );
    final body = response.data as Map;
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Không tải được dữ liệu');
    }
    return body['data'];
  }

  Future<void> _load() async {
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait([
        _call('GET', 'shifts'),
        _call(
          'GET',
          'schedules',
          query: {
            'from': BranchHelpers.dateToYmd(_from),
            'to': BranchHelpers.dateToYmd(_to),
            if (_store != null) 'storeId': _store,
          },
        ),
        _call(
          'GET',
          'roster/settings',
          query: {if (_store != null) 'storeId': _store},
        ),
      ]);
      if (!mounted || version != _version) return;
      setState(() {
        _shifts = (data[0] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _schedules = (data[1] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _settings = (data[2] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      if (mounted && version == _version) {
        setState(() => _error = readableApiError(e));
      }
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? shift]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TemplateForm(
        shift: shift,
        save: (data) async {
          await _call(
            shift == null ? 'POST' : 'PUT',
            shift == null ? 'shifts' : 'shifts/${shift['id']}',
            data: data,
          );
        },
      ),
    );
    if (saved == true && mounted) await _load();
  }

  void _changeDate(DateTime date) {
    setState(() {
      _anchor = DateUtils.dateOnly(date);
      _day = _anchor;
    });
    _load();
  }

  void _move(int direction) => _changeDate(
    _period == 'Month'
        ? DateTime(_anchor.year, _anchor.month + direction, 1)
        : _anchor.add(Duration(days: direction * (_period == 'Day' ? 1 : 7))),
  );

  Future<void> _transfer(Map<String, dynamic> item) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShiftTransferDialog(
        schedule: item,
        stores: widget.stores
            .where((s) => s['id'] != item['storeId'] && s['status'] != 'CLOSED')
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList(),
        onSave: (target) async {
          await _call(
            'PUT',
            'schedules/${item['id']}/transfer',
            data: {'sourceStoreId': item['storeId'], 'targetStoreId': target},
          );
        },
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã điều chuyển ca làm.')));
      await _load();
    }
  }

  bool _canTransfer(Map<String, dynamic> item) {
    final starts = DateTime.tryParse(
      '${item['startsAt'] ?? '${item['date']}T${item['startTime']}'}',
    );
    return !_loading &&
        item['status'] == 'PENDING' &&
        item['storeId'] != null &&
        starts != null &&
        starts.isAfter(DateTime.now()) &&
        widget.stores.any(
          (s) => s['id'] == item['storeId'] && s['status'] != 'CLOSED',
        ) &&
        widget.stores.any(
          (s) => s['id'] != item['storeId'] && s['status'] != 'CLOSED',
        );
  }

  List<Map<String, dynamic>> _plans(dynamic storeId) {
    final settings = _settings
        .where((s) => s['storeId'] == storeId)
        .firstOrNull;
    final plans = (settings?['plans'] as List? ?? []).whereType<Map>();
    return [
      for (final slot in rosterSlots.keys)
        Map<String, dynamic>.from(
          plans.where((p) => p['slot'] == slot).firstOrNull ??
              (() {
                final shift = _shifts
                    .where(
                      (s) => s['active'] != false && scheduleSlot(s) == slot,
                    )
                    .firstOrNull;
                return {
                  'slot': slot,
                  'shiftId': shift?['id'],
                  'shiftName': shift?['name'],
                  'startTime': shift?['startTime'],
                  'endTime': shift?['endTime'],
                  'active': shift != null,
                  'requiredStaff': 0,
                };
              })(),
        ),
    ];
  }

  Widget _branchDay(DateTime day, Map<String, dynamic> branch) {
    final plans = _plans(branch['id']);
    Widget block(Map<String, dynamic> plan) => ScheduleRosterBlock(
      plan: plan,
      filter: _filter,
      assignments: _schedules
          .where(
            (s) =>
                s['date'] == BranchHelpers.dateToYmd(day) &&
                s['storeId'] == branch['id'] &&
                scheduleSlot(s) == plan['slot'] &&
                s['status'] != 'CANCELLED',
          )
          .toList(),
      action: (item) => _canTransfer(item)
          ? IconButton(
              tooltip: 'Điều chuyển ca',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _transfer(item),
            )
          : null,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${branch['name']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 1000
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < plans.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: block(plans[i])),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      for (final plan in plans)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: block(plan),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _calendar() {
    final counts = <String, int>{};
    for (final row in _schedules.where((s) => s['status'] != 'CANCELLED')) {
      counts['${row['date']}'] = (counts['${row['date']}'] ?? 0) + 1;
    }
    final branches = <Map<String, dynamic>>[
      for (final store in widget.stores)
        if ((_store == null || store['id'] == _store) &&
            (store['status'] != 'CLOSED' ||
                _schedules.any((s) => s['storeId'] == store['id'])))
          Map<String, dynamic>.from(store as Map),
      if (_schedules.any((s) => s['storeId'] == null))
        {'id': null, 'name': 'Chưa có chi nhánh'},
    ];
    final days = _period == 'Week' && _day != null
        ? [_day!]
        : List.generate(
            _to.difference(_from).inDays + 1,
            (i) => _from.add(Duration(days: i)),
          );
    return [
      DropdownButtonFormField<int>(
        initialValue: _store ?? 0,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Chi nhánh'),
        items: [
          const DropdownMenuItem(value: 0, child: Text('Tất cả chi nhánh')),
          ...widget.stores.map(
            (s) => DropdownMenuItem<int>(
              value: s['id'] as int,
              child: Text('${s['name']}', overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: _loading
            ? null
            : (v) {
                setState(() => _store = v == 0 ? null : v);
                _load();
              },
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Day', label: Text('Ngày')),
              ButtonSegment(value: 'Week', label: Text('Tuần')),
              ButtonSegment(value: 'Month', label: Text('Tháng')),
            ],
            selected: {_period},
            onSelectionChanged: _loading
                ? null
                : (v) {
                    setState(() {
                      _period = v.first;
                      _day = _anchor;
                    });
                    _load();
                  },
          ),
          TextButton(
            onPressed: _loading ? null : () => _changeDate(DateTime.now()),
            child: const Text('Hôm nay'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          IconButton(
            tooltip: 'Kỳ trước',
            onPressed: _loading ? null : () => _move(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _anchor,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100, 12, 31),
                      );
                      if (date != null && mounted) _changeDate(date);
                    },
              child: Text(
                '${BranchHelpers.shortDate(_from)} – ${BranchHelpers.prettyDate(_to)}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kỳ sau',
            onPressed: _loading ? null : () => _move(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      if (_period == 'Week') ...[
        ScheduleWeekStrip(
          from: _from,
          selected: _day,
          counts: counts,
          onSelected: (day) => setState(() {
            _day = day;
            _anchor = day;
          }),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _day = null),
            child: const Text('Xem cả tuần'),
          ),
        ),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in {
            'ALL': 'Tất cả',
            'DRAFT': 'Bản nháp',
            'PUBLISHED': 'Đã công bố',
          }.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: _filter == entry.key,
              onSelected: (_) => setState(() => _filter = entry.key),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Định mức tính cả nháp và lịch đã công bố; không tính nghỉ phép, vắng mặt hoặc ca đã hủy.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 12),
      const InlineNotice(
        'Bấm biểu tượng ⇄ cạnh nhân viên để chuyển ca sang chi nhánh khác. Giữ nguyên ngày, giờ và chi nhánh chính của nhân viên.',
      ),
      const SizedBox(height: 16),
      if (_schedules.isEmpty && !_loading)
        const EmptyStateView(
          icon: Icons.event_note_outlined,
          title: 'Chưa có lịch trong kỳ',
          message: 'Manager của chi nhánh sẽ tạo và công bố lịch.',
        ),
      if (!_loading)
        for (final day in days) ...[
          Text(
            BranchHelpers.prettyDate(day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final branch in branches) _branchDay(day, branch),
        ],
    ];
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        PageHeading(
          title: 'Lịch làm toàn chuỗi',
          subtitle: 'Theo dõi nhân sự theo ca và điều chuyển giữa các chi nhánh',
          action: _templates
              ? FilledButton.icon(
                  onPressed: _loading ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo mẫu ca'),
                )
              : null,
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.calendar_month_outlined),
              label: Text('Lịch chi nhánh'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.tune),
              label: Text('Mẫu ca'),
            ),
          ],
          selected: {_templates},
          onSelectionChanged: (v) => setState(() => _templates = v.first),
        ),
        const SizedBox(height: 20),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          InlineNotice(_error!, error: true),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ] else if (_templates) ...[
          const InlineNotice(
            'Mẫu ca dùng chung toàn chuỗi. Ngừng sử dụng sẽ chặn phân ca mới và giữ lịch cũ. Sửa mẫu đã dùng sẽ tạo phiên bản mới.',
          ),
          const SizedBox(height: 16),
          if (_shifts.isEmpty && !_loading)
            const EmptyStateView(
              icon: Icons.schedule,
              title: 'Chưa có mẫu ca',
              message: 'Tạo mẫu ca để Manager bắt đầu phân lịch.',
            ),
          for (final shift in _shifts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${shift['name']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sửa mẫu ca',
                          onPressed: _loading ? null : () => _edit(shift),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    Text(
                      '${shortTime(shift['startTime'])} – ${shortTime(shift['endTime'])} · Nghỉ ${shift['breakMinutes']} phút',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      shift['active'] == true
                          ? 'Đang sử dụng'
                          : 'Đã ngừng sử dụng',
                      style: TextStyle(
                        color: shift['active'] == true
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ] else
          ..._calendar(),
      ],
    ),
  );
}

class _TemplateForm extends StatefulWidget {
  final Map<String, dynamic>? shift;
  final Future<void> Function(Map<String, dynamic>) save;
  const _TemplateForm({this.shift, required this.save});
  @override
  State<_TemplateForm> createState() => _TemplateFormState();
}

class _TemplateFormState extends State<_TemplateForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.shift?['name'] as String? ?? '',
  );
  late final _break = TextEditingController(
    text: '${widget.shift?['breakMinutes'] ?? 0}',
  );
  late TimeOfDay _start = _time(widget.shift?['startTime'], 8),
      _end = _time(widget.shift?['endTime'], 16);
  late bool _active = widget.shift?['active'] != false;
  bool _saving = false;
  String? _error;
  TimeOfDay _time(dynamic value, int fallback) {
    final parts = value?.toString().split(':');
    return parts == null
        ? TimeOfDay(hour: fallback, minute: 0)
        : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _clock(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  @override
  void dispose() {
    _name.dispose();
    _break.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final duration =
        (_end.hour * 60 +
            _end.minute -
            _start.hour * 60 -
            _start.minute +
            1440) %
        1440;
    if (duration == 0 || int.parse(_break.text) >= duration) {
      setState(
        () => _error = 'Giờ kết thúc phải khác giờ bắt đầu; thời gian nghỉ phải nhỏ hơn độ dài ca.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save({
        'name': _name.text.trim(),
        'startTime': _clock(_start),
        'endTime': _clock(_end),
        'breakMinutes': int.parse(_break.text),
        'active': _active,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = readableApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: widget.shift == null ? 'Tạo mẫu ca' : 'Sửa mẫu ca',
    saving: _saving,
    actions: [
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Đang lưu…' : 'Lưu mẫu ca'),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) InlineNotice(_error!, error: true),
          TextFormField(
            controller: _name,
            enabled: !_saving,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Tên ca'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập tên ca' : null,
          ),
          const SizedBox(height: 16),
          for (final start in [true, false])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(
                  '${start ? 'Bắt đầu' : 'Kết thúc'} · ${_clock(start ? _start : _end)}',
                ),
                onPressed: _saving
                    ? null
                    : () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: start ? _start : _end,
                        );
                        if (time != null && mounted) {
                          setState(() {
                            if (start) {
                              _start = time;
                            } else {
                              _end = time;
                            }
                          });
                        }
                      },
              ),
            ),
          TextFormField(
            controller: _break,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nghỉ giữa ca (phút)'),
            validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0
                ? 'Nhập số phút hợp lệ'
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cho phép sử dụng'),
            value: _active,
            onChanged: _saving ? null : (v) => setState(() => _active = v),
          ),
          const InlineNotice(
            'Nếu giờ kết thúc sớm hơn giờ bắt đầu, ca sẽ kết thúc vào ngày hôm sau.',
          ),
        ],
      ),
    ),
  );
}
