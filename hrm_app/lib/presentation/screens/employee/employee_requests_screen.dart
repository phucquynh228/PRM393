import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../widgets/content_widgets.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/status_badge.dart';
import '../branch/branch_helpers.dart';
import 'request_form.dart';

class EmployeeRequestsScreen extends StatefulWidget {
  const EmployeeRequestsScreen({super.key});
  @override
  State<EmployeeRequestsScreen> createState() => _EmployeeRequestsScreenState();
}

class _EmployeeRequestsScreenState extends State<EmployeeRequestsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await context.read<Dio>().get('/requests/mine');
      final body = response.data as Map;
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Chưa tải được yêu cầu');
      }
      final data = (body['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
          .reversed
          .toList();
      if (mounted) setState(() => _items = data);
    } catch (e) {
      if (mounted) setState(() => _error = requestError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await RequestForm.show(context, context.read<Dio>());
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu tới quản lý.')),
      );
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items
        .where((e) => _filter == 'ALL' || e['status'] == _filter)
        .toList();
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          PageHeading(
            title: 'Yêu cầu của tôi',
            subtitle: 'Theo dõi đơn nghỉ phép và đổi ca',
            action: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Tạo yêu cầu'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in [
                ('ALL', 'Tất cả'),
                ('PENDING', 'Chờ duyệt'),
                ('APPROVED', 'Đã duyệt'),
                ('REJECTED', 'Từ chối'),
              ])
                ChoiceChip(
                  label: Text(filter.$2),
                  selected: _filter == filter.$1,
                  onSelected: (_) => setState(() => _filter = filter.$1),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            InlineNotice(_error!, error: true),
            TextButton(onPressed: _reload, child: const Text('Thử lại')),
          ] else if (!_loading && items.isEmpty)
            EmptyStateView(
              icon: Icons.mail_outline,
              title: 'Chưa có yêu cầu phù hợp',
              message: 'Gửi đơn mới khi bạn cần nghỉ phép hoặc đổi ca.',
              buttonText: 'Tạo yêu cầu',
              onButtonPressed: _create,
            ),
          ...items.map(
            (item) => Padding(
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
                          item['type'] == 'LEAVE' ? 'Nghỉ phép' : 'Đổi ca',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        StatusBadge.fromStatus(item['status']?.toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${BranchHelpers.formatIsoDate(item['startDate'])} → ${BranchHelpers.formatIsoDate(item['endDate'])}',
                    ),
                    const SizedBox(height: 8),
                    Text(item['reason']?.toString() ?? ''),
                    if (item['managerNote']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      InlineNotice('Quản lý: ${item['managerNote']}'),
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
