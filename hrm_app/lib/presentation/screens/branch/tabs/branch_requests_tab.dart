import 'package:flutter/material.dart';

import '../../../widgets/content_widgets.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/status_badge.dart';
import '../branch_helpers.dart';
import '../dialogs/branch_request_decision_dialog.dart';

class BranchRequestsTab extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final String requestFilter;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function(String method, String path, {Object? data})
  onSend;
  final Future<void> Function() onReloadRequests;
  final void Function(String, {bool isError}) showMessage;
  final String Function(dynamic) cleanError;
  const BranchRequestsTab({
    super.key,
    required this.requests,
    required this.requestFilter,
    required this.onFilterChanged,
    required this.onSend,
    required this.onReloadRequests,
    required this.showMessage,
    required this.cleanError,
  });
  @override
  State<BranchRequestsTab> createState() => _BranchRequestsTabState();
}

class _BranchRequestsTabState extends State<BranchRequestsTab> {
  final Set<int> _busy = {};
  Future<void> _decide(Map<String, dynamic> request, bool approved) async {
    final id = request['id'] as int;
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await BranchRequestDecisionDialog.show(
        context,
        request: request,
        approved: approved,
        onConfirm: (note) async {
          await widget.onSend(
            'PUT',
            '/manager/requests/$id',
            data: {
              'status': approved ? 'APPROVED' : 'REJECTED',
              if (note != null) 'managerNote': note,
            },
          );
          await widget.onReloadRequests();
          widget.showMessage(
            approved ? 'Đã duyệt yêu cầu.' : 'Đã từ chối yêu cầu.',
          );
        },
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.requests
        .where(
          (item) =>
              widget.requestFilter == 'All' ||
              (widget.requestFilter == 'Processed'
                  ? item['status'] != 'PENDING'
                  : item['status'] == 'PENDING'),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: widget.onReloadRequests,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const PageHeading(
            title: 'Duyệt yêu cầu',
            subtitle: 'Đơn nghỉ phép và đổi ca từ đội ngũ',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in [
                ('Pending', 'Chờ duyệt'),
                ('Processed', 'Đã xử lý'),
                ('All', 'Tất cả'),
              ])
                ChoiceChip(
                  label: Text(filter.$2),
                  selected: widget.requestFilter == filter.$1,
                  onSelected: (_) => widget.onFilterChanged(filter.$1),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            const EmptyStateView(
              icon: Icons.mark_email_read_outlined,
              title: 'Đã xử lý hết',
              message: 'Không có yêu cầu phù hợp với bộ lọc hiện tại.',
            ),
          ...filtered.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          item['userName'] ?? 'Nhân viên',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        StatusBadge.fromStatus(item['status']),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(item['type'] == 'LEAVE' ? 'Nghỉ phép' : 'Đổi ca'),
                    const SizedBox(height: 6),
                    Text(
                      '${BranchHelpers.formatIsoDate(item['startDate'])} → ${BranchHelpers.formatIsoDate(item['endDate'])}',
                    ),
                    const SizedBox(height: 12),
                    Text(item['reason']?.toString() ?? ''),
                    if (item['managerNote']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      InlineNotice('Ghi chú: ${item['managerNote']}'),
                    ],
                    if (item['status'] == 'PENDING') ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy.contains(item['id'])
                                ? null
                                : () => _decide(item, true),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Duyệt đơn'),
                          ),
                          OutlinedButton(
                            onPressed: _busy.contains(item['id'])
                                ? null
                                : () => _decide(item, false),
                            child: const Text('Từ chối'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
