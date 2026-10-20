import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../blocs/home/home_bloc.dart';
import '../blocs/home/home_event.dart';
import '../blocs/home/home_state.dart';
import '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Dio _requestDio;

  @override
  void initState() {
    super.initState();
    _requestDio = Dio(BaseOptions(baseUrl: globalBaseUrl));
    _requestDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          const storage = FlutterSecureStorage();
          final token = await storage.read(key: 'jwt_token');
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
    // Load schedules when screen opens
    context.read<HomeBloc>().add(LoadSchedules());
  }

  @override
  void dispose() {
    _requestDio.close();
    super.dispose();
  }

  Future<void> _showRequests() async {
    try {
      final response = await _requestDio.get('/requests/mine');
      final data = response.data is Map ? response.data['data'] : null;
      final requests = data is List
          ? data
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Yêu cầu của tôi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRequestForm();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo đơn'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: requests.isEmpty
                      ? const Center(child: Text('Bạn chưa gửi yêu cầu nào'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            final approved = request['status'] == 'APPROVED';
                            final pending = request['status'] == 'PENDING';
                            final statusColor = pending
                                ? Colors.orange
                                : approved
                                ? Colors.green
                                : Colors.red;
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  request['type'] == 'LEAVE'
                                      ? Icons.beach_access_outlined
                                      : Icons.swap_horiz,
                                  color: Colors.brown,
                                ),
                                title: Text(
                                  request['type'] == 'LEAVE'
                                      ? 'Xin nghỉ phép'
                                      : 'Yêu cầu đổi ca',
                                ),
                                subtitle: Text(
                                  '${request['startDate']} — ${request['endDate']}\n${request['reason']}',
                                ),
                                isThreeLine: true,
                                trailing: Text(
                                  pending
                                      ? 'Chờ duyệt'
                                      : approved
                                      ? 'Đã duyệt'
                                      : 'Từ chối',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } on DioException catch (error) {
      _showSnackBar(
        error.response?.data is Map
            ? error.response?.data['message']?.toString() ??
                  'Không tải được yêu cầu'
            : error.message ?? 'Không tải được yêu cầu',
        isError: true,
      );
    }
  }

  Future<void> _showRequestForm() async {
    final formKey = GlobalKey<FormState>();
    final reason = TextEditingController();
    var requestType = 'LEAVE';
    var startDate = DateUtils.dateOnly(DateTime.now());
    var endDate = startDate;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tạo yêu cầu',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: requestType,
                  decoration: const InputDecoration(
                    labelText: 'Loại yêu cầu',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'LEAVE',
                      child: Text('Xin nghỉ phép'),
                    ),
                    DropdownMenuItem(
                      value: 'SHIFT_SWAP',
                      child: Text('Xin đổi ca'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() {
                        requestType = value;
                        if (value == 'SHIFT_SWAP') endDate = startDate;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final value = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateUtils.dateOnly(DateTime.now()),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (value != null) {
                            setSheetState(() {
                              startDate = DateUtils.dateOnly(value);
                              if (endDate.isBefore(startDate) ||
                                  requestType == 'SHIFT_SWAP') {
                                endDate = startDate;
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.event),
                        label: Text('Từ ${_formatDate(startDate)}'),
                      ),
                    ),
                    if (requestType == 'LEAVE') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await showDatePicker(
                              context: context,
                              initialDate: endDate.isBefore(startDate)
                                  ? startDate
                                  : endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (value != null) {
                              setSheetState(
                                () => endDate = DateUtils.dateOnly(value),
                              );
                            }
                          },
                          icon: const Icon(Icons.event_available),
                          label: Text('Đến ${_formatDate(endDate)}'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: reason,
                  maxLines: 3,
                  maxLength: 1000,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập lý do'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Lý do',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.brown[700],
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        await _requestDio.post(
                          '/requests',
                          data: {
                            'type': requestType,
                            'startDate': _isoDate(startDate),
                            'endDate': _isoDate(endDate),
                            'reason': reason.text.trim(),
                          },
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        _showSnackBar('Đã gửi yêu cầu cho quản lý');
                      } on DioException catch (error) {
                        final message = error.response?.data is Map
                            ? error.response?.data['message']?.toString()
                            : null;
                        _showSnackBar(
                          message ?? error.message ?? 'Không gửi được yêu cầu',
                          isError: true,
                        );
                      }
                    },
                    child: const Text('Gửi yêu cầu'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    reason.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ca làm việc hôm nay'),
        backgroundColor: Colors.brown[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Đơn nghỉ và đổi ca',
            icon: const Icon(Icons.mark_email_unread_outlined),
            onPressed: _showRequests,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<HomeBloc>().add(LoadSchedules());
            },
          ),
        ],
      ),
      body: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is HomeError) {
            _showSnackBar(
              state.error.replaceAll('Exception: ', ''),
              isError: true,
            );
          } else if (state is HomeActionSuccess) {
            _showSnackBar(state.message);
          }
        },
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HomeLoaded) {
            final schedules = state.schedules;
            if (schedules.isEmpty) {
              return const Center(
                child: Text('Hôm nay bạn không có ca làm việc nào.'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.shiftName ?? 'Ca làm việc',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thời gian: ${schedule.startTime} - ${schedule.endTime}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trạng thái: ${schedule.status}',
                          style: TextStyle(
                            fontSize: 16,
                            color: schedule.status == 'PENDING'
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.read<HomeBloc>().add(
                                    CheckInRequested(
                                      scheduleId: schedule.resolvedId,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.login),
                                label: const Text('Check-in'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Call check-out, using 0 if attendanceId is not known here
                                  context.read<HomeBloc>().add(
                                    const CheckOutRequested(attendanceId: 0),
                                  );
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Check-out'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          return const Center(child: Text('Vui lòng làm mới trang'));
        },
      ),
    );
  }
}
