import 'package:flutter/material.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/schedule_roster_block.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/schedule_week_strip.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/fixed_roster_editor.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';
import 'package:hrm_app/features/branch/presentation/dialogs/branch_schedule_sheet.dart';
import 'package:hrm_app/features/branch/presentation/dialogs/shift_roster_dialogs.dart';

class BranchScheduleTab extends StatefulWidget {
  final List<Map<String, dynamic>> schedules, staff, shifts, plans;
  final String schedulePeriod;
  final bool dataReady;
  final DateTime selectedDate, scheduleFrom, scheduleTo;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function(String method, String path, {Object? data})
  onSend;
  final Future<void> Function() onReloadSchedules;
  final Future<Map<String, dynamic>> Function(DateTime)? onGenerateWeek;
  final void Function(String, {bool isError}) showMessage;
  final String Function(dynamic) cleanError;
  final Future<void> Function({
    required DateTime initial,
    DateTime? firstDate,
    DateTime? lastDate,
    required ValueChanged<DateTime> onPicked,
  })
  onPickDate;
  const BranchScheduleTab({
    super.key,
    required this.schedules,
    required this.staff,
    required this.shifts,
    this.plans = const [],
    this.dataReady = true,
    required this.schedulePeriod,
    required this.selectedDate,
    required this.scheduleFrom,
    required this.scheduleTo,
    required this.onPeriodChanged,
    required this.onDateChanged,
    required this.onSend,
    required this.onReloadSchedules,
    required this.showMessage,
    required this.cleanError,
    required this.onPickDate,
    this.onGenerateWeek,
  });
  @override
  State<BranchScheduleTab> createState() => _BranchScheduleTabState();
}

class _BranchScheduleTabState extends State<BranchScheduleTab> {
  late DateTime? _day = widget.schedulePeriod == 'Week'
      ? widget.selectedDate
      : null;
  String _filter = 'ALL';
  bool _working = false;
  bool get _blocked => _working || !widget.dataReady;
  final Set<int> _busy = {};
  List<Map<String, dynamic>> get _plans => [
    for (final slot in rosterSlots.keys)
      widget.plans.where((p) => p['slot'] == slot).firstOrNull ??
          (() {
            final shift = widget.shifts
                .where((s) => s['active'] != false && scheduleSlot(s) == slot)
                .firstOrNull;
            return <String, dynamic>{
              'slot': slot,
              'shiftId': shift?['id'],
              'shiftName': shift?['name'],
              'startTime': shift?['startTime'],
              'endTime': shift?['endTime'],
              'requiredStaff': 0,
              'active': shift != null,
            };
          })(),
  ];
  @override
  void didUpdateWidget(covariant BranchScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleFrom != widget.scheduleFrom ||
        oldWidget.schedulePeriod != widget.schedulePeriod) {
      _day = widget.schedulePeriod == 'Week' ? widget.selectedDate : null;
    }
  }

  void _move(int direction) => widget.onDateChanged(
    widget.schedulePeriod == 'Month'
        ? DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month + direction,
            1,
          )
        : widget.selectedDate.add(
            Duration(
              days: direction * (widget.schedulePeriod == 'Day' ? 1 : 7),
            ),
          ),
  );

  Future<void> _settings() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShiftStaffingSettingsDialog(
        plans: _plans,
        shifts: widget.shifts.where((s) => s['active'] != false).toList(),
        cleanError: widget.cleanError,
        onSave: (slots) => widget.onSend(
          'PUT',
          '/manager/roster/settings',
          data: {'slots': slots},
        ),
      ),
    );
    if (saved == true) {
      await widget.onReloadSchedules();
      widget.showMessage('Đã lưu định mức nhân sự theo ca.');
    }
  }

  Future<void> _add(
    DateTime date,
    Map<String, dynamic> plan,
    List<Map<String, dynamic>> assignments,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShiftStaffPicker(
        slot: plan['slot'] as String,
        date: date,
        staff: widget.staff,
        assignments: assignments,
        cleanError: widget.cleanError,
        onSave: (ids) => widget.onSend(
          'POST',
          '/manager/schedules/batch',
          data: {
            'date': BranchHelpers.dateToYmd(date),
            'slot': plan['slot'],
            'userIds': ids,
          },
        ),
      ),
    );
    if (saved == true) {
      await widget.onReloadSchedules();
      widget.showMessage('Đã thêm nhân sự vào bản nháp.');
    }
  }

  Future<void> _generate() async {
    if (_blocked || widget.onGenerateWeek == null) return;
    setState(() => _working = true);
    try {
      final result = await widget.onGenerateWeek!(widget.scheduleFrom);
      if (!mounted) return;
      final skipped = (result['skipped'] as List? ?? [])
          .whereType<Map>()
          .toList();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã tạo lịch nháp tuần'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result['created'] ?? 0} ca mới · ${result['existing'] ?? 0} ca đã có · ${skipped.length} ca bỏ qua',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kiểm tra định mức, điều chỉnh nhân sự rồi bấm Công bố. Lịch đang có được giữ nguyên.',
                  ),
                  for (final row in skipped)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${row['userName']} · ${row['date']} · ${rosterSlots[row['slot']]}\n${row['reason']}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (error) {
      widget.showMessage(widget.cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _publishAll() async {
    if (_blocked) return;
    setState(() => _working = true);
    try {
      await widget.onSend(
        'POST',
        '/manager/schedules/publish?from=${BranchHelpers.dateToYmd(widget.scheduleFrom)}&to=${BranchHelpers.dateToYmd(widget.scheduleTo)}',
      );
      await widget.onReloadSchedules();
      widget.showMessage('Đã công bố lịch trong khoảng đang xem.');
    } catch (error) {
      widget.showMessage(widget.cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _action(String action, Map<String, dynamic> item) async {
    if (action == 'edit') {
      await BranchScheduleSheet.show(
        context,
        schedule: item,
        staff: widget.staff,
        shifts: widget.shifts,
        schedules: widget.schedules,
        initialDate: widget.selectedDate,
        onSend: widget.onSend,
        onReload: widget.onReloadSchedules,
        showMessage: widget.showMessage,
        cleanError: widget.cleanError,
        onPickDate: widget.onPickDate,
      );
      return;
    }
    final id = (item['id'] as num).toInt();
    if (_busy.contains(id)) return;
    Future<void> run() async {
      if (!mounted) return;
      setState(() => _busy.add(id));
      try {
        await widget.onSend(
          action == 'publish' ? 'POST' : 'DELETE',
          '/manager/schedules/$id${action == 'publish' ? '/publish' : ''}',
        );
        await widget.onReloadSchedules();
        widget.showMessage(
          action == 'publish' ? 'Đã công bố ca làm.' : 'Đã xóa ca làm.',
        );
      } catch (error) {
        widget.showMessage(widget.cleanError(error), isError: true);
      } finally {
        if (mounted) setState(() => _busy.remove(id));
      }
    }

    if (action == 'delete') {
      await BranchScheduleSheet.confirmDelete(
        context,
        schedule: item,
        onConfirm: run,
      );
    } else {
      await run();
    }
  }

  bool _future(Map<String, dynamic> row) {
    final starts = DateTime.tryParse(
      '${row['startsAt'] ?? '${row['date']}T${row['startTime']}'}',
    );
    return row['status'] == 'PENDING' &&
        starts != null &&
        starts.isAfter(DateTime.now());
  }

  Widget _block(DateTime date, Map<String, dynamic> plan) {
    final slot = plan['slot'] as String;
    final assignments = widget.schedules
        .where(
          (s) =>
              s['date'] == BranchHelpers.dateToYmd(date) &&
              scheduleSlot(s) == slot &&
              s['status'] != 'CANCELLED',
        )
        .toList();
    final starts = DateTime.tryParse(
      '${BranchHelpers.dateToYmd(date)}T${plan['startTime'] ?? '00:00:00'}',
    );
    final canAdd =
        !_blocked &&
        widget.staff.isNotEmpty &&
        plan['active'] == true &&
        starts != null &&
        starts.isAfter(DateTime.now());
    return ScheduleRosterBlock(
      plan: plan,
      assignments: assignments,
      filter: _filter,
      action: (item) => _future(item)
          ? PopupMenuButton<String>(
              tooltip: 'Thao tác ca làm',
              enabled: !_blocked && !_busy.contains(item['id']),
              onSelected: (action) => _action(action, item),
              itemBuilder: (_) => [
                if (item['published'] != true)
                  const PopupMenuItem(
                    value: 'publish',
                    child: Text('Công bố ca'),
                  ),
                if (widget.staff.any((s) => s['id'] == item['userId']))
                  const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                const PopupMenuItem(value: 'delete', child: Text('Xóa ca')),
              ],
            )
          : null,
      footer: OutlinedButton.icon(
        onPressed: canAdd ? () => _add(date, plan, assignments) : null,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Thêm nhân sự'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drafts = widget.schedules
        .where((s) => s['published'] != true && s['status'] == 'PENDING')
        .length;
    final counts = <String, int>{};
    for (final row in widget.schedules.where(
      (s) => s['status'] != 'CANCELLED',
    )) {
      counts['${row['date']}'] = (counts['${row['date']}'] ?? 0) + 1;
    }
    final days = _day != null && widget.schedulePeriod == 'Week'
        ? [_day!]
        : List.generate(
            widget.scheduleTo.difference(widget.scheduleFrom).inDays + 1,
            (i) => widget.scheduleFrom.add(Duration(days: i)),
          );
    return LayoutBuilder(
      builder: (context, box) => RefreshIndicator(
        onRefresh: widget.onReloadSchedules,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const PageHeading(
              title: 'Lịch làm chi nhánh',
              subtitle: 'Phân nhân sự theo ca · Tạo nháp trước khi công bố',
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Day', label: Text('Ngày')),
                    ButtonSegment(value: 'Week', label: Text('Tuần')),
                    ButtonSegment(value: 'Month', label: Text('Tháng')),
                  ],
                  selected: {widget.schedulePeriod},
                  onSelectionChanged: _working
                      ? null
                      : (s) => widget.onPeriodChanged(s.first),
                ),
                OutlinedButton.icon(
                  onPressed: _blocked ? null : _settings,
                  icon: const Icon(Icons.tune),
                  label: const Text('Định mức ca'),
                ),
                if (widget.schedulePeriod == 'Week')
                  OutlinedButton.icon(
                    onPressed:
                        _blocked ||
                            widget.onGenerateWeek == null ||
                            widget.scheduleTo.isBefore(
                              DateUtils.dateOnly(DateTime.now()),
                            )
                        ? null
                        : _generate,
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: const Text('Tạo nháp tuần mới'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Kỳ trước',
                  onPressed: _working ? null : () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _working
                        ? null
                        : () => widget.onPickDate(
                            initial: widget.selectedDate,
                            onPicked: widget.onDateChanged,
                          ),
                    child: Text(
                      '${BranchHelpers.shortDate(widget.scheduleFrom)} – ${BranchHelpers.prettyDate(widget.scheduleTo)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kỳ sau',
                  onPressed: _working ? null : () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (widget.schedulePeriod == 'Week') ...[
              ScheduleWeekStrip(
                from: widget.scheduleFrom,
                selected: _day,
                counts: counts,
                onSelected: (day) => setState(() => _day = day),
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
                FilledButton.tonalIcon(
                  onPressed: _blocked || drafts == 0 ? null : _publishAll,
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(
                    _working ? 'Đang xử lý…' : 'Công bố $drafts ca nháp',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Định mức tính cả nháp và lịch đã công bố; không tính nghỉ phép, vắng mặt hoặc ca đã hủy.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            for (final day in days) ...[
              Text(
                BranchHelpers.prettyDate(day),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (box.maxWidth >= 1000)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _plans.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: _block(day, _plans[i])),
                    ],
                  ],
                )
              else
                ..._plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _block(day, plan),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
