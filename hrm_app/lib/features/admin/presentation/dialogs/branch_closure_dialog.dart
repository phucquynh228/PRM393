import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hrm_app/core/config/api_config.dart';
import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';

/// The same placement form is used when closing a branch or assigning waiting staff.
class BranchClosureDialog extends StatefulWidget {
  final Dio dio;
  final List<dynamic> stores;
  final Map<String, dynamic>? store, employee;
  const BranchClosureDialog({
    super.key,
    required this.dio,
    required this.stores,
    this.store,
    this.employee,
  }) : assert((store == null) != (employee == null));

  static Future<bool?> show(
    BuildContext context, {
    required Dio dio,
    required List<dynamic> stores,
    Map<String, dynamic>? store,
    Map<String, dynamic>? employee,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BranchClosureDialog(
      dio: dio,
      stores: stores,
      store: store,
      employee: employee,
    ),
  );
  @override
  State<BranchClosureDialog> createState() => _BranchClosureDialogState();
}

class _BranchClosureDialogState extends State<BranchClosureDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final Map<int, String?> _actions = {};
  final Map<int, int?> _targets = {};
  final Set<int> _managers = {};
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _preview;
  String? _error;
  bool _loading = true, _saving = false, _confirmed = false;
  bool get _closing => widget.store != null;
  bool get _blocked =>
      (_preview?['openAttendances'] as num? ?? 0) > 0 ||
      _preview?['status'] == 'CLOSED';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_closing) {
        final result = await widget.dio.get(
          '$globalBaseUrl/admin/stores/${widget.store!['id']}/closure-preview',
        );
        final body = result.data as Map;
        if (body['success'] != true) {
          throw Exception(
            body['message'] ?? 'Không tải được thông tin chi nhánh',
          );
        }
        _preview = Map<String, dynamic>.from(body['data'] as Map);
        _employees = (_preview!['employees'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _employees = [widget.employee!];
      }
    } catch (e) {
      if (mounted) setState(() => _error = readableApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _placement(Map<String, dynamic> person) {
    final id = person['id'] as int;
    final action = _actions[id];
    return {
      'userId': id,
      'action': action,
      if (action == 'TRANSFER') 'targetStoreId': _targets[id],
      'manager': action == 'TRANSFER' && _managers.contains(id),
    };
  }

  Future<void> _save() async {
    if (_saving ||
        _loading ||
        _blocked ||
        !_confirmed ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.dio.request(
        _closing
            ? '$globalBaseUrl/admin/stores/${widget.store!['id']}/close'
            : '$globalBaseUrl/admin/users/${widget.employee!['id']}/placement',
        options: Options(method: _closing ? 'POST' : 'PUT'),
        data: _closing
            ? {
                'reason': _reason.text.trim(),
                'placements': _employees.map(_placement).toList(),
              }
            : _placement(_employees.single),
      );
      final body = result.data as Map;
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Không lưu được thay đổi');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = readableApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setAction(int id, String? action) {
    _actions[id] = action;
    _targets.remove(id);
    _managers.remove(id);
    _confirmed = false;
  }

  Widget _person(Map<String, dynamic> person) {
    final id = person['id'] as int;
    final destinations = widget.stores
        .where(
          (s) =>
              s['status'] == 'ACTIVE' &&
              s['id'] != (widget.store?['id'] ?? person['storeId']),
        )
        .toList();
    final target = destinations
        .where((s) => s['id'] == _targets[id])
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${person['name']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('${person['phone']}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge.fromStatus(person['role']),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('action-$id-${_actions[id]}'),
              initialValue: _actions[id],
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cách xử lý'),
              items: const [
                DropdownMenuItem(
                  value: 'TRANSFER',
                  child: Text('Điều chuyển chi nhánh'),
                ),
                DropdownMenuItem(
                  value: 'WAITING_TRANSFER',
                  child: Text('Chờ điều chuyển'),
                ),
                DropdownMenuItem(
                  value: 'INACTIVE',
                  child: Text('Ngừng làm việc'),
                ),
              ],
              validator: (v) => v == null ? 'Chọn cách xử lý nhân viên' : null,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _setAction(id, v)),
            ),
            if (_actions[id] == 'TRANSFER') ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: ValueKey('target-$id-${_targets[id]}'),
                initialValue: _targets[id],
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Chi nhánh nhận'),
                items: destinations
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text(
                          '${s['name']} · ${s['currentStaffCount'] ?? 0}/${s['maxStaff']} người',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (v) =>
                    v == null ? 'Chọn chi nhánh đang hoạt động' : null,
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                        _targets[id] = v;
                        _managers.remove(id);
                        _confirmed = false;
                      }),
              ),
              if (person['role'] == 'MANAGER') ...[
                const SizedBox(height: 8),
                const Text(
                  'Quyền quản lý chi nhánh cũ sẽ kết thúc. Mặc định làm nhân viên tại nơi nhận.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bổ nhiệm Manager tại nơi nhận'),
                  subtitle: target?['managerId'] != null
                      ? const Text('Chi nhánh nhận đã có Manager')
                      : null,
                  value: _managers.contains(id),
                  onChanged:
                      _saving || target == null || target['managerId'] != null
                      ? null
                      : (v) => setState(() {
                          if (v == true) {
                            _managers.add(id);
                          } else {
                            _managers.remove(id);
                          }
                          _confirmed = false;
                        }),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: _closing ? 'Ngừng hoạt động chi nhánh' : 'Bố trí nhân sự',
    saving: _saving,
    actions: [
      OutlinedButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        onPressed:
            _loading ||
                _saving ||
                _blocked ||
                !_confirmed ||
                _error != null && _preview == null && _closing
            ? null
            : _save,
        child: Text(
          _saving
              ? 'Đang xử lý…'
              : _closing
              ? 'Xác nhận ngừng hoạt động'
              : 'Lưu bố trí',
        ),
      ),
    ],
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  InlineNotice(_error!, error: true),
                  if (_preview == null && _closing)
                    TextButton(
                      onPressed: _load,
                      child: const Text('Tải lại thông tin'),
                    ),
                  const SizedBox(height: 14),
                ],
                if (_closing && _preview != null) ...[
                  Text(
                    '${widget.store!['name']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  InlineNotice(
                    '${_employees.length} nhân viên/Manager · ${_preview!['futureSchedules']} ca sắp tới · ${_preview!['pendingRequests']} yêu cầu đang chờ.\n'
                    'Các ca sắp tới và yêu cầu đang chờ liên quan sẽ được hủy, kèm thông báo. Lịch sử vẫn giữ chi nhánh gốc.',
                  ),
                  if ((_preview!['adminAccounts'] as num? ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Tài khoản Admin sẽ được gỡ khỏi chi nhánh và tiếp tục sử dụng bình thường.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reason,
                    enabled: !_saving,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Lý do ngừng hoạt động',
                    ),
                    onChanged: (_) => setState(() => _confirmed = false),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nhập lý do ngừng hoạt động'
                        : null,
                  ),
                ],
                if (_blocked) ...[
                  const InlineNotice(
                    'Không thể đóng: chi nhánh đã đóng hoặc còn nhân viên chưa check-out. Xử lý ca đang làm rồi tải lại.',
                    error: true,
                  ),
                  if ((_preview?['workingEmployees'] as List? ?? []).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Chưa check-out: ${(_preview!['workingEmployees'] as List).map((p) => p['name']).join(', ')}',
                      ),
                    ),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Kiểm tra lại'),
                  ),
                ] else if (!_closing || _preview != null) ...[
                  const SizedBox(height: 12),
                  if (_closing && _employees.length > 1) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Áp dụng cho tất cả (tùy chọn)',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'TRANSFER',
                          child: Text('Điều chuyển'),
                        ),
                        DropdownMenuItem(
                          value: 'WAITING_TRANSFER',
                          child: Text('Chờ điều chuyển'),
                        ),
                        DropdownMenuItem(
                          value: 'INACTIVE',
                          child: Text('Ngừng làm việc'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              for (final p in _employees) {
                                _setAction(p['id'] as int, v);
                              }
                            }),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ..._employees.map(_person),
                  const InlineNotice(
                    'Chờ điều chuyển: vẫn đăng nhập và xem lịch sử, chưa được phân ca. Ngừng làm việc: tài khoản bị khóa. Khi chuyển nơi làm, quản lý phân lịch mới.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmed,
                    title: const Text(
                      'Tôi xác nhận phương án xử lý và hủy các ca/yêu cầu sắp tới liên quan.',
                    ),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _confirmed = v == true),
                  ),
                ],
              ],
            ),
          ),
  );
}
