import 'package:flutter/material.dart';

import 'package:hrm_app/features/staff/data/repositories/staff_repository.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';

const staffRequestTypes = {
  'LEAVE': 'Nghỉ phép',
  'UNPAID_LEAVE': 'Nghỉ không lương',
  'SHIFT_SWAP': 'Đổi ca',
  'ATTENDANCE_CORRECTION': 'Điều chỉnh chấm công',
};
String requestType(Object? type) => staffRequestTypes[type] ?? 'Yêu cầu';
String compactHours(Object? value) {
  final minutes = (value as num? ?? 0).toInt();
  return '${minutes ~/ 60}h ${minutes % 60}p';
}

String minutesLabel(Object? value) {
  final minutes = (value as num? ?? 0).toInt();
  return '${minutes ~/ 60} giờ ${minutes % 60} phút';
}

String shortTime(Object? value) {
  final text = value?.toString() ?? '';
  return text.length >= 5 ? text.substring(0, 5) : '—';
}

String stamp(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? '—'
      : '${BranchHelpers.prettyDate(date)} · ${BranchHelpers.clockTime(date)}';
}

String shiftLabel(StaffItem item, {bool person = false}) =>
    '${person ? '${item['userName']} · ' : ''}${BranchHelpers.formatIsoDate(item['date'])} · ${item['shiftName']} · ${shortTime(item['startTime'])}–${shortTime(item['endTime'])}';

Future<bool> staffConfirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;
