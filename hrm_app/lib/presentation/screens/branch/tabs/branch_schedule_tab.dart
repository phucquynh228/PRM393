import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/content_widgets.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/status_badge.dart';
import '../../../widgets/schedule_week_strip.dart';
import '../branch_helpers.dart';
import '../dialogs/branch_schedule_sheet.dart';

class BranchScheduleTab extends StatefulWidget {
  final List<Map<String, dynamic>> schedules, staff, shifts;
  final String schedulePeriod;
  final DateTime selectedDate, scheduleFrom, scheduleTo;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function(String method, String path, {Object? data})
  onSend;
  final Future<void> Function() onReloadSchedules;
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
  });
  @override
  State<BranchScheduleTab> createState() => _BranchScheduleTabState();
}

class _BranchScheduleTabState extends State<BranchScheduleTab> {
  final Set<int> _busy = {};
  String _filter = 'ALL';
  DateTime? _day;
  bool _publishing = false;

  @override
  void didUpdateWidget(covariant BranchScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleFrom != widget.scheduleFrom ||
        oldWidget.schedulePeriod != widget.schedulePeriod) {
      _day = null;
    }
  }

  Future<void> _publishAll() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      await widget.onSend(
        'POST',
        '/manager/schedules/publish?from=${BranchHelpers.dateToYmd(widget.scheduleFrom)}&to=${BranchHelpers.dateToYmd(widget.scheduleTo)}',
      );
      await widget.onReloadSchedules();
      widget.showMessage('Đã công bố lịch trong khoảng đang xem.');
    } catch (e) {
      widget.showMessage(widget.cleanError(e), isError: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _form([Map<String, dynamic>? schedule]) => BranchScheduleSheet.show(
    context,
    schedule: schedule,
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
  Future<void> _action(String action, Map<String, dynamic> item) async {
    if (action == 'edit') {
      _form(item);
      return;
    }
    final id = item['id'] as int;
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
      } catch (e) {
        widget.showMessage(widget.cleanError(e), isError: true);
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

  Widget _menu(Map<String, dynamic> item) => PopupMenuButton<String>(
    tooltip: 'Thao tác ca làm',
    enabled: !_busy.contains(item['id']),
    onSelected: (action) => _action(action, item),
    itemBuilder: (_) => [
      if (item['published'] != true)
        const PopupMenuItem(value: 'publish', child: Text('Công bố ca')),
      const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
      const PopupMenuItem(value: 'delete', child: Text('Xóa ca')),
    ],
  );
  Widget _card(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item['userName'] ?? 'Nhân viên',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (item['status'] == 'PENDING') _menu(item),
            ],
          ),
          Text(
            '${item['shiftName']} · ${item['startTime']} – ${item['endTime']}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge.fromStatus(
                item['published'] == true ? 'PUBLISHED' : 'DRAFT',
              ),
              if (item['status'] != 'PENDING')
                StatusBadge.fromStatus(item['status']),
            ],
          ),
          if (_busy.contains(item['id']))
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    ),
  );

  Widget _weekGrid() {
    final days = List.generate(
      7,
      (i) => widget.scheduleFrom.add(Duration(days: i)),
    );
    return Table(
      border: TableBorder.all(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(12),
      ),
      columnWidths: const {0: FixedColumnWidth(170)},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceVariant),
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Nhân viên',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ...days.map(
              (d) => Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '${d.weekday == 7 ? 'CN' : 'T${d.weekday + 1}'}\n${BranchHelpers.shortDate(d)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        ...widget.staff.map(
          (person) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(person['name'] ?? '—'),
              ),
              ...days.map((day) {
                final shifts = widget.schedules.where(
                  (s) =>
                      s['userId'] == person['id'] &&
                      s['date'] == BranchHelpers.dateToYmd(day),
                );
                return Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shifts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('—'),
                        ),
                      ...shifts.map(
                        (s) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: s['published'] == true
                                ? AppColors.successBg
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['shiftName'] ?? 'Ca làm',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${s['startTime']}\n${s['endTime']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                s['published'] == true
                                    ? 'Đã công bố'
                                    : 'Bản nháp',
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (s['status'] == 'PENDING') _menu(s),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final counts = <String, int>{};
    final drafts = widget.schedules.where((s) => s['published'] != true).length;
    final visible = widget.schedules
        .where(
          (s) =>
              (_filter == 'ALL' ||
                  (_filter == 'DRAFT'
                      ? s['published'] != true
                      : s['published'] == true)) &&
              (_day == null || s['date'] == BranchHelpers.dateToYmd(_day!)),
        )
        .toList();
    for (final item in widget.schedules) {
      counts['${item['date']}'] = (counts['${item['date']}'] ?? 0) + 1;
    }
    for (final item in visible) {
      (grouped[item['date']?.toString() ?? ''] ??= []).add(item);
    }
    final dates = grouped.keys.toList()..sort();
    return LayoutBuilder(
      builder: (context, box) => RefreshIndicator(
        onRefresh: widget.onReloadSchedules,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            PageHeading(
              title: 'Lịch làm chi nhánh',
              subtitle:
                  '${widget.schedules.length} phân công · $drafts nháp · ${widget.schedules.length - drafts} đã công bố',
              action: FilledButton.icon(
                onPressed: widget.staff.isEmpty || widget.shifts.isEmpty
                    ? null
                    : () => _form(),
                icon: const Icon(Icons.add),
                label: const Text('Phân ca'),
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Day', label: Text('Ngày')),
                    ButtonSegment(value: 'Week', label: Text('Tuần')),
                    ButtonSegment(value: 'Month', label: Text('Tháng')),
                  ],
                  selected: {widget.schedulePeriod},
                  onSelectionChanged: (s) => widget.onPeriodChanged(s.first),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Kỳ trước',
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: () => widget.onPickDate(
                          initial: widget.selectedDate,
                          onPicked: widget.onDateChanged,
                        ),
                        child: Text(
                          widget.schedulePeriod == 'Day'
                              ? BranchHelpers.prettyDate(widget.selectedDate)
                              : '${BranchHelpers.shortDate(widget.scheduleFrom)} – ${BranchHelpers.prettyDate(widget.scheduleTo)}',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kỳ sau',
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 10,
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
                  onPressed: drafts == 0 || _publishing ? null : _publishAll,
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(
                    _publishing ? 'Đang công bố…' : 'Công bố $drafts ca nháp',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
              const SizedBox(height: 12),
            ],
            if (widget.shifts.isNotEmpty) ...[
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Mẫu ca được phép sử dụng'),
                children: widget.shifts
                    .map(
                      (s) => ListTile(
                        dense: true,
                        title: Text(
                          '${s['name']} · ${s['startTime']} – ${s['endTime']}',
                        ),
                        subtitle: Text(
                          'Nghỉ giữa ca ${s['breakMinutes'] ?? 0} phút',
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.staff.isEmpty || widget.shifts.isEmpty) ...[
              const InlineNotice(
                'Cần có nhân viên và mẫu ca làm trước khi phân ca.',
              ),
              const SizedBox(height: 16),
            ],
            if (visible.isEmpty)
              const EmptyStateView(
                icon: Icons.event_note_outlined,
                title: 'Chưa có lịch phân ca',
                message: 'Thêm ca làm mới hoặc chọn khoảng ngày khác.',
              )
            else if (box.maxWidth >= 1100 &&
                widget.schedulePeriod == 'Week' &&
                _day == null &&
                _filter == 'ALL')
              _weekGrid()
            else
              ...dates.map(
                (date) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        BranchHelpers.formatIsoDate(date),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...grouped[date]!.map(_card),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
