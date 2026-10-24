import 'package:dio/dio.dart';

import 'package:hrm_app/core/network/api_error.dart';

import 'package:flutter/material.dart';

import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';

String requestError(Object error) => readableApiError(error);

class RequestForm extends StatefulWidget {
  final Dio dio;
  const RequestForm({super.key, required this.dio});
  static Future<bool?> show(BuildContext context, Dio dio) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => RequestForm(dio: dio),
      );
  @override
  State<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<RequestForm> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String _type = 'LEAVE';
  DateTime _start = DateUtils.dateOnly(DateTime.now());
  late DateTime _end = _start;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final day = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: start ? now : _start,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day != null && mounted) {
      setState(() {
        if (start) {
          _start = day;
          if (_end.isBefore(day) || _type == 'SHIFT_SWAP') _end = day;
        } else {
          _end = day;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await widget.dio.post(
        '/requests',
        data: {
          'type': _type,
          'startDate': BranchHelpers.dateToYmd(_start),
          'endDate': BranchHelpers.dateToYmd(
            _type == 'SHIFT_SWAP' ? _start : _end,
          ),
          'reason': _reason.text.trim(),
        },
      );
      if ((response.data as Map)['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gửi yêu cầu thất bại');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = requestError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tạo yêu cầu',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Quản lý chi nhánh sẽ xem và phản hồi đơn của bạn.'),
              const SizedBox(height: 24),
              if (_error != null) ...[
                InlineNotice(_error!, error: true),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Loại yêu cầu'),
                items: const [
                  DropdownMenuItem(value: 'LEAVE', child: Text('Nghỉ phép')),
                  DropdownMenuItem(value: 'SHIFT_SWAP', child: Text('Đổi ca')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _type = value!;
                        if (_type == 'SHIFT_SWAP') _end = _start;
                      }),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _pick(true),
                icon: const Icon(Icons.event_outlined),
                label: Text('Từ ngày ${BranchHelpers.prettyDate(_start)}'),
              ),
              if (_type == 'LEAVE') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pick(false),
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Đến ngày ${BranchHelpers.prettyDate(_end)}'),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _reason,
                enabled: !_saving,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Lý do',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập lý do'
                    : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Đang gửi…' : 'Gửi yêu cầu'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
