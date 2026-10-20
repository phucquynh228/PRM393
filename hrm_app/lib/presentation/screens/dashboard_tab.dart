import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home/home_bloc.dart';
import '../blocs/home/home_event.dart';
import '../blocs/home/home_state.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listener: (context, state) {
        if (state is HomeError) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red));
        } else if (state is HomeActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green));
        }
      },
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<HomeBloc>().add(LoadSchedules());
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Ca làm việc hôm nay',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown)),
              const SizedBox(height: 16),
              if (state is HomeLoading)
                const Center(child: CircularProgressIndicator())
              else if (state is HomeLoaded && state.schedules.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Text('Hôm nay bạn không có ca làm việc nào.',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                )
              else if (state is HomeLoaded)
                ...state.schedules.map((schedule) {
                  // Phân tích trạng thái để khóa/mở nút theo BR-ATT-02 và BR-ATT-04
                  final status = schedule.status ?? 'PENDING';
                  final isCanceled = status == 'CANCELED';
                  final canCheckIn = status == 'PENDING';
                  final canCheckOut = status == 'CHECKED_IN' || status == 'IN_PROGRESS';

                  Color statusColor = Colors.orange;
                  String statusText = 'Chưa làm';
                  if (status == 'CHECKED_IN' || status == 'IN_PROGRESS') {
                    statusColor = Colors.blue;
                    statusText = 'Đang làm';
                  } else if (status == 'COMPLETED' || status == 'CHECKED_OUT') {
                    statusColor = Colors.green;
                    statusText = 'Hoàn thành';
                  } else if (isCanceled) {
                    statusColor = Colors.red;
                    statusText = 'Đã hủy';
                  }

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                schedule.shiftName ?? 'Ca làm việc',
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold, 
                                  color: isCanceled ? Colors.grey : Colors.brown,
                                  decoration: isCanceled ? TextDecoration.lineThrough : null,
                                )
                              ),
                              Chip(
                                label: Text(statusText,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                backgroundColor: statusColor,
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('Thời gian: ${schedule.startTime} - ${schedule.endTime}',
                                  style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.location_on, size: 18, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Vị trí: Tại cửa hàng', style: TextStyle(fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: canCheckIn ? () => context
                                      .read<HomeBloc>()
                                      .add(CheckInRequested(scheduleId: schedule.resolvedId)) : null,
                                  icon: const Icon(Icons.login),
                                  label: const Text('Check-in'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    disabledBackgroundColor: Colors.grey[300],
                                    disabledForegroundColor: Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: canCheckOut ? () => context
                                      .read<HomeBloc>()
                                      .add(const CheckOutRequested(attendanceId: 0)) : null, // Cần cập nhật ID từ API sau
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Check-out'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    disabledBackgroundColor: Colors.grey[300],
                                    disabledForegroundColor: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
