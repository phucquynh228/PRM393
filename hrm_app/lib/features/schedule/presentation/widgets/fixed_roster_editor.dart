import 'package:flutter/material.dart';

const rosterSlots = {
  'MORNING': 'Ca Sáng',
  'AFTERNOON': 'Ca Chiều',
  'EVENING': 'Ca Tối',
};

List<Map<String, dynamic>> rosterEntries(Set<String> selected) => [
  for (int day = 1; day <= 7; day++)
    for (final slot in rosterSlots.keys)
      if (selected.contains('$day:$slot')) {'dayOfWeek': day, 'slot': slot},
];

Set<String> rosterSelection(dynamic entries) => entries is List
    ? entries
          .whereType<Map>()
          .map((entry) => '${entry['dayOfWeek']}:${entry['slot']}')
          .toSet()
    : {};

class FixedRosterEditor extends StatelessWidget {
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<Set<String>> onChanged;
  const FixedRosterEditor({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Ca làm việc mặc định',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Chọn ca cố định theo thứ. Ca này dùng để tạo nháp tuần mới; nhân viên chỉ nhận lịch sau khi công bố.',
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const SizedBox(width: 48),
          for (final slot in rosterSlots.values)
            Expanded(
              child: Text(
                slot,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      for (int day = 1; day <= 7; day++)
        Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(day == 7 ? 'CN' : 'Thứ ${day + 1}'),
            ),
            for (final slot in rosterSlots.keys)
              Expanded(
                child: Semantics(
                  label:
                      '${day == 7 ? 'Chủ nhật' : 'Thứ ${day + 1}'} ${rosterSlots[slot]}',
                  child: Checkbox(
                    value: selected.contains('$day:$slot'),
                    onChanged: !enabled
                        ? null
                        : (checked) {
                            final next = {...selected};
                            if (checked == true) {
                              next.add('$day:$slot');
                            } else {
                              next.remove('$day:$slot');
                            }
                            onChanged(next);
                          },
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}

class FixedRosterSummary extends StatelessWidget {
  final dynamic entries;
  const FixedRosterSummary({super.key, required this.entries});
  @override
  Widget build(BuildContext context) {
    final selected = rosterSelection(entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ca làm việc mặc định',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (selected.isEmpty)
          const Text('Chưa thiết lập ca mặc định.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in rosterEntries(selected))
                Chip(
                  label: Text(
                    '${entry['dayOfWeek'] == 7 ? 'CN' : 'T${(entry['dayOfWeek'] as int) + 1}'} · ${rosterSlots[entry['slot']]}',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        const Text(
          'Quản lý thiết lập khi tuyển dụng. Lịch chính thức có thể thay đổi theo đơn nghỉ và chỉ có hiệu lực sau khi công bố.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
