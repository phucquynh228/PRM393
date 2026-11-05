import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/features/auth/data/repositories/password_support_repository.dart';
import 'package:hrm_app/features/admin/presentation/dialogs/password_support_decision_dialog.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/empty_state_view.dart';

class PasswordSupportScreen extends StatefulWidget {
  final Dio dio;
  const PasswordSupportScreen({super.key, required this.dio});

  @override
  State<PasswordSupportScreen> createState() => _PasswordSupportScreenState();
}

class _PasswordSupportScreenState extends State<PasswordSupportScreen> {
  late final _repository = PasswordSupportRepository(widget.dio);
  List<Map<String, dynamic>> _items = [];
  String _status = 'PENDING';
  String? _error;
  bool _loading = true;
  int _version = 0;
  static const _labels = {
    'PENDING': 'Chờ xử lý',
    'RESOLVED': 'Đã đặt lại',
    'REJECTED': 'Đã từ chối',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.list(_status);
      if (mounted && version == _version) setState(() => _items = items);
    } catch (error) {
      if (mounted && version == _version) {
        setState(() => _error = readableApiError(error));
      }
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> request, bool resolve) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordSupportDecisionDialog(
        repository: _repository,
        request: request,
        resolve: resolve,
      ),
    );
    if (!mounted || changed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resolve
              ? 'Đã đặt lại mật khẩu. Hãy trao trực tiếp cho nhân viên đã xác minh.'
              : 'Đã từ chối yêu cầu hỗ trợ.',
        ),
      ),
    );
    await _load();
  }

  String _date(Object? value) {
    final date = DateTime.tryParse('$value');
    if (date == null) return '—';
    String two(int n) => '$n'.padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Hỗ trợ mật khẩu'),
      actions: [
        IconButton(
          tooltip: 'Làm mới yêu cầu',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Xác minh trực tiếp với nhân viên trước khi đặt lại mật khẩu. Hiển thị tối đa 100 yêu cầu gần nhất theo trạng thái.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái yêu cầu',
                  ),
                  items: _labels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null || value == _status) return;
                          setState(() {
                            _status = value;
                            _items = [];
                          });
                          _load();
                        },
                ),
                const SizedBox(height: 20),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  InlineNotice(_error!, error: true),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
                if (!_loading && _error == null && _items.isEmpty)
                  const EmptyStateView(
                    icon: Icons.support_agent,
                    title: 'Chưa có yêu cầu',
                    message:
                        'Các yêu cầu hỗ trợ mật khẩu sẽ xuất hiện tại đây.',
                  ),
                for (final item in _items) ...[
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['name']} · ${item['phone']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item['storeName'] ?? 'Chưa phân chi nhánh'} · ${_date(item['createdAt'])}',
                        ),
                        const SizedBox(height: 12),
                        Text('Tên người gửi tự khai: ${item['requestedName']}'),
                        if (item['note'] != null)
                          Text('Ghi chú người gửi: ${item['note']}'),
                        if (item['handledBy'] != null)
                          Text(
                            'Xử lý bởi: ${item['handledBy']} · ${_date(item['handledAt'])}',
                          ),
                        if (item['adminNote'] != null)
                          Text('Ghi chú Admin: ${item['adminNote']}'),
                        if (item['status'] == 'PENDING') ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _decide(item, true),
                                icon: const Icon(Icons.lock_reset),
                                label: const Text('Đặt lại mật khẩu'),
                              ),
                              OutlinedButton(
                                onPressed: _loading
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
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
