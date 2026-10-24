import 'package:flutter/material.dart';

import '../../../data/repositories/staff_repository.dart';
import '../../blocs/staff/staff_cubit.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/schedule_week_strip.dart';
import '../branch/branch_helpers.dart';
import 'staff_shift_card.dart';

class StaffScheduleTab extends StatefulWidget {
  final StaffState state;
  final Future<void> Function() refresh;
  final void Function({DateTime? anchor, bool? month}) change;
  final ValueChanged<StaffItem> details, swap;
  final VoidCallback? request;
  const StaffScheduleTab({
    super.key,
    required this.state,
    required this.refresh,
    required this.change,
    required this.details,
    required this.swap,
    this.request,
  });

  @override
  State<StaffScheduleTab> createState() => _StaffScheduleTabState();
}

class _StaffScheduleTabState extends State<StaffScheduleTab> {
  DateTime? _selected;
  StaffState get state => widget.state;

  @override
  void didUpdateWidget(covariant StaffScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.from != state.from ||
        oldWidget.state.month != state.month) {
      _selected = null;
    }
  }

  bool canSwap(StaffItem item) =>
      item['status'] == 'PENDING' &&
      (DateTime.tryParse('${item['startsAt']}')?.isAfter(DateTime.now()) ??
          false);

  void move(int direction) => widget.change(
    anchor: state.month
        ? DateTime(state.anchor.year, state.anchor.month + direction, 1)
        : state.anchor.add(Duration(days: direction * 7)),
  );

  @override
  Widget build(BuildContext context) {
    final all = state.items('schedules');
    final items = all
        .where(
          (s) =>
              _selected == null ||
              s['date'] == ScheduleWeekStrip.keyOf(_selected!),
        )
        .toList();
    final now = DateTime.now();
    bool upcoming(StaffItem s) =>
        DateTime.tryParse('${s['endsAt']}')?.isAfter(now) ?? false;
    items.sort((a, b) {
      if (upcoming(a) != upcoming(b)) return upcoming(a) ? -1 : 1;
      return '${a['startsAt']}'.compareTo('${b['startsAt']}');
    });
    final counts = <String, int>{};
    for (final item in all) {
      counts['${item['date']}'] = (counts['${item['date']}'] ?? 0) + 1;
    }
    final days = items.map((s) => '${s['date']}').toSet().toList();
    return RefreshIndicator(
      onRefresh: widget.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const PageHeading(
            title: 'Lịch làm việc',
            subtitle: 'Chỉ hiển thị lịch đã được quản lý công bố',
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Tuần')),
                  ButtonSegment(value: true, label: Text('Tháng')),
                ],
                selected: {state.month},
                onSelectionChanged: state.busy
                    ? null
                    : (v) => widget.change(month: v.first),
              ),
              OutlinedButton.icon(
                onPressed: state.busy
                    ? null
                    : () => widget.change(anchor: DateTime.now()),
                icon: const Icon(Icons.today),
                label: const Text('Hôm nay'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Khoảng trước',
                  onPressed: state.busy ? null : () => move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: state.busy
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: state.anchor,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) widget.change(anchor: date);
                          },
                    child: Text(
                      '${BranchHelpers.prettyDate(state.from)} – ${BranchHelpers.prettyDate(state.to)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Khoảng tiếp theo',
                  onPressed: state.busy ? null : () => move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!state.month) ...[
            ScheduleWeekStrip(
              from: state.from,
              selected: _selected,
              counts: counts,
              onSelected: (day) => setState(() => _selected = day),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _selected = null),
                child: const Text('Xem cả tuần · Ca sắp tới trước'),
              ),
            ),
          ],
          if (items.isEmpty && !state.loading)
            const EmptyStateView(
              icon: Icons.calendar_month_outlined,
              title: 'Chưa có lịch trong khoảng này',
              message: 'Chọn tuần/tháng khác hoặc chờ quản lý công bố lịch.',
            ),
          for (final day in days) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                BranchHelpers.formatIsoDate(day),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final item in items.where((s) => s['date'] == day))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StaffShiftCard(
                  schedule: item,
                  busy: state.busy || state.loading,
                  onDetails: () => widget.details(item),
                  onSwap: canSwap(item) ? () => widget.swap(item) : null,
                ),
              ),
          ],
          const SizedBox(height: 16),
          if (widget.request != null)
            FilledButton.icon(
              onPressed: state.busy ? null : widget.request,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Gửi yêu cầu đổi ca / xin nghỉ'),
            ),
        ],
      ),
    );
  }
}
