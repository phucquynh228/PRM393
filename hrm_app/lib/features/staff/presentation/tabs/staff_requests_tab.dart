import 'package:flutter/material.dart';

import 'package:hrm_app/features/staff/data/repositories/staff_repository.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/empty_state_view.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';
import 'package:hrm_app/features/staff/presentation/helpers/staff_helpers.dart';

class StaffRequestsTab extends StatefulWidget {
  final List<StaffItem> items;
  final bool busy;
  final Future<void> Function() refresh;
  final VoidCallback create;
  final ValueChanged<int> cancel;
  const StaffRequestsTab({
    super.key,
    required this.items,
    required this.busy,
    required this.refresh,
    required this.create,
    required this.cancel,
  });
  @override
  State<StaffRequestsTab> createState() => _StaffRequestsTabState();
}

class _StaffRequestsTabState extends State<StaffRequestsTab> {
  String _status = 'ALL', _type = 'ALL';
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where(
          (r) =>
              (_status == 'ALL' || r['status'] == _status) &&
              (_type == 'ALL' || r['type'] == _type),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: widget.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          PageHeading(
            title: 'Yêu cầu của tôi',
            subtitle: 'Nghỉ phép, đổi ca và điều chỉnh chấm công',
            action: FilledButton.icon(
              onPressed: widget.busy ? null : widget.create,
              icon: const Icon(Icons.add),
              label: const Text('Tạo yêu cầu'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in {
                'ALL': 'Tất cả',
                'PENDING': 'Chờ duyệt',
                'APPROVED': 'Đã duyệt',
                'REJECTED': 'Từ chối',
                'CANCELLED': 'Đã hủy',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _status == entry.key,
                  onSelected: (_) => setState(() => _status = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Loại yêu cầu'),
            items: {'ALL': 'Tất cả loại yêu cầu', ...staffRequestTypes}.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const EmptyStateView(
              icon: Icons.mail_outline,
              title: 'Chưa có yêu cầu phù hợp',
              message: 'Tạo đơn mới hoặc chọn bộ lọc khác để xem kết quả.',
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          requestType(item['type']),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        StatusBadge.fromStatus('${item['status']}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '#${item['id']} · ${BranchHelpers.formatIsoDate(item['startDate'])} → ${BranchHelpers.formatIsoDate(item['endDate'])}',
                    ),
                    const SizedBox(height: 8),
                    Text('${item['reason'] ?? ''}'),
                    if (item['sourceScheduleId'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Ca của bạn: #${item['sourceScheduleId']}'),
                    ],
                    if (item['targetScheduleId'] != null)
                      Text('Ca muốn nhận: #${item['targetScheduleId']}'),
                    if (item['requestedCheckIn'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Giờ vào đề xuất: ${stamp(item['requestedCheckIn'])}',
                      ),
                      Text(
                        'Giờ ra đề xuất: ${stamp(item['requestedCheckOut'])}',
                      ),
                    ],
                    if ('${item['managerNote'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InlineNotice(
                        'Phản hồi quản lý: ${item['managerNote']}',
                        error: item['status'] == 'REJECTED',
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Đã gửi: ${stamp(item['createdAt'])}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item['canCancel'] == true)
                      TextButton.icon(
                        onPressed: widget.busy
                            ? null
                            : () async {
                                final confirmed = await staffConfirm(
                                  context,
                                  'Hủy yêu cầu?',
                                  'Đơn #${item['id']} sẽ được hủy nếu vẫn còn chờ duyệt.',
                                );
                                if (confirmed) widget.cancel(item['id'] as int);
                              },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Hủy yêu cầu'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
