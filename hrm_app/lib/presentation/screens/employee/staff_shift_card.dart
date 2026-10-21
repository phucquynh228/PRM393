import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/staff_repository.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/status_badge.dart';
import 'staff_helpers.dart';

class StaffShiftCard extends StatelessWidget {
  final StaffItem schedule;
  final StaffItem? record;
  final bool busy, attendanceActions;
  final VoidCallback? onCheckIn, onCheckOut, onSwap, onDetails;
  const StaffShiftCard({
    super.key,
    required this.schedule,
    this.record,
    this.busy = false,
    this.attendanceActions = false,
    this.onCheckIn,
    this.onCheckOut,
    this.onSwap,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final pending = schedule['status'] == 'PENDING',
        working = schedule['status'] == 'CHECKED_IN';
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${schedule['shiftName'] ?? 'Ca làm'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              StatusBadge.fromStatus(
                pending ? 'NOT_CHECKED_IN' : '${schedule['status']}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${shortTime(schedule['startTime'])} – ${shortTime(schedule['endTime'])}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${schedule['storeName'] ?? 'Chưa gán chi nhánh'}${schedule['storeCode'] == null ? '' : ' · ${schedule['storeCode']}'}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (record != null) ...[
            const SizedBox(height: 10),
            Text('Vào ca: ${stamp(record!['checkInTime'])}'),
            if (record!['checkOutTime'] != null)
              Text('Ra ca: ${stamp(record!['checkOutTime'])}'),
          ],
          if (attendanceActions && (pending || working)) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : working
                  ? onCheckOut
                  : onCheckIn,
              icon: Icon(working ? Icons.logout_rounded : Icons.login_rounded),
              label: Text(
                busy
                    ? 'Đang xử lý…'
                    : working
                    ? 'Check-out · Kết thúc ca'
                    : 'Check-in · Bắt đầu ca',
              ),
            ),
            if (working && onCheckOut == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Chưa tải được bản ghi vào ca. Hãy làm mới để thử lại.',
                ),
              ),
          ],
          if (onDetails != null || onSwap != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onDetails != null)
                  TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Chi tiết ca'),
                  ),
                if (onSwap != null)
                  TextButton.icon(
                    onPressed: busy ? null : onSwap,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Đề nghị đổi ca'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
