import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/core/config/api_config.dart';
import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/empty_state_view.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';
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
  List<Map<String, dynamic>> _shifts = [], _schedules = [];
  DateTime _anchor = DateUtils.dateOnly(DateTime.now());
  int? _store;
  bool _loading = true, _templates = false;
  String? _error;
  int _version = 0;
  DateTime get _from => _anchor.subtract(Duration(days: _anchor.weekday - 1));
  DateTime get _to => _from.add(const Duration(days: 6));

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
      ]);
      if (!mounted || version != _version) return;
      setState(() {
        _shifts = (data[0] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _schedules = (data[1] as List)
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

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        PageHeading(
          title: 'Lịch làm toàn chuỗi',
          subtitle: 'Cấu hình mẫu ca và theo dõi lịch tại các chi nhánh',
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
        ] else ...[
          DropdownButtonFormField<int>(
            initialValue: _store ?? 0,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Chi nhánh'),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Tất cả chi nhánh')),
              ...widget.stores.map(
                (s) => DropdownMenuItem<int>(
                  value: s['id'] as int,
                  child: Text('${s['name']}'),
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
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Tuần trước',
                onPressed: _loading
                    ? null
                    : () {
                        setState(
                          () => _anchor = _anchor.subtract(
                            const Duration(days: 7),
                          ),
                        );
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${BranchHelpers.shortDate(_from)} – ${BranchHelpers.prettyDate(_to)}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Tuần sau',
                onPressed: _loading
                    ? null
                    : () {
                        setState(
                          () => _anchor = _anchor.add(const Duration(days: 7)),
                        );
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(
                        () => _anchor = DateUtils.dateOnly(DateTime.now()),
                      );
                      _load();
                    },
              child: const Text('Tuần hiện tại'),
            ),
          ),
          if (_schedules.isEmpty && !_loading)
            const EmptyStateView(
              icon: Icons.event_note_outlined,
              title: 'Chưa có lịch trong tuần',
              message: 'Manager của chi nhánh sẽ tạo và công bố lịch.',
            ),
          for (final s in _schedules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s['storeName'] ?? 'Chưa có chi nhánh'} · ${BranchHelpers.formatIsoDate(s['date'])}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${s['userName']} · ${s['shiftName']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${shortTime(s['startTime'])} – ${shortTime(s['endTime'])}',
                    ),
                    const SizedBox(height: 10),
                    StatusBadge.fromStatus(
                      s['published'] == true ? 'PUBLISHED' : 'DRAFT',
                    ),
                  ],
                ),
              ),
            ),
        ],
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
