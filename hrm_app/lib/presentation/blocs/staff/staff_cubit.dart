import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_error.dart';
import '../../../data/repositories/staff_repository.dart';
import '../../../domain/repositories/attendance_repository.dart';

class StaffState {
  final StaffItem data;
  final DateTime anchor;
  final bool month, loading, busy, initialized;
  final String? error, message;
  StaffState({
    this.data = const {},
    required this.anchor,
    this.month = false,
    this.loading = false,
    this.busy = false,
    this.initialized = false,
    this.error,
    this.message,
  });

  DateTime get from => month
      ? DateTime(anchor.year, anchor.month, 1)
      : DateTime(anchor.year, anchor.month, anchor.day - anchor.weekday + 1);
  DateTime get to => month
      ? DateTime(anchor.year, anchor.month + 1, 0)
      : from.add(const Duration(days: 6));
  StaffItem get profile =>
      Map<String, dynamic>.from(data['profile'] as Map? ?? {});
  List<StaffItem> items(String key) => staffItems(data[key]);
  int get unread =>
      items('notifications').where((n) => n['read'] != true).length;
  int get pending =>
      items('requests').where((r) => r['status'] == 'PENDING').length;

  StaffState copy({
    StaffItem? data,
    DateTime? anchor,
    bool? month,
    bool? loading,
    bool? busy,
    bool? initialized,
    String? error,
    String? message,
  }) => StaffState(
    data: data ?? this.data,
    anchor: anchor ?? this.anchor,
    month: month ?? this.month,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    initialized: initialized ?? this.initialized,
    error: error,
    message: message,
  );
}

class StaffCubit extends Cubit<StaffState> {
  final StaffRepository repository;
  final AttendanceRepository attendance;
  int _loadId = 0;
  StaffCubit(this.repository, this.attendance)
    : super(StaffState(anchor: DateTime.now()));

  Future<void> load({DateTime? anchor, bool? month}) async {
    if (state.busy) return;
    await _load(anchor: anchor, month: month);
  }

  Future<void> _load({DateTime? anchor, bool? month, String? message}) async {
    final id = ++_loadId;
    emit(state.copy(anchor: anchor, month: month, loading: true));
    final from = state.from, to = state.to;
    try {
      final data = await repository.workspace(from, to);
      if (isClosed || id != _loadId) return;
      emit(
        state.copy(
          data: data,
          loading: false,
          busy: false,
          initialized: true,
          message: message,
        ),
      );
    } catch (e) {
      if (isClosed || id != _loadId) return;
      emit(
        state.copy(
          loading: false,
          busy: false,
          error: message == null
              ? readableApiError(e)
              : '$message Chưa tải lại được dữ liệu. Hãy làm mới.',
        ),
      );
    }
  }

  Future<void> act(Future<void> Function() action, String message) async {
    if (state.busy || state.loading || isClosed) return;
    ++_loadId;
    emit(state.copy(busy: true));
    try {
      await action();
    } catch (e) {
      if (!isClosed) emit(state.copy(busy: false, error: readableApiError(e)));
      return;
    }
    if (!isClosed) await _load(message: message);
  }

  Future<void> checkIn(int id) =>
      act(() => attendance.checkIn(id), 'Đã check-in vào ca.');
  Future<void> checkOut(int id) =>
      act(() => attendance.checkOut(id), 'Đã check-out kết thúc ca.');
  Future<void> cancel(int id) => act(() async {
    await repository.send('PUT', '/requests/$id/cancel');
  }, 'Đã hủy yêu cầu.');
  Future<void> readNotification(int id) => act(() async {
    await repository.send('PUT', '/staff/notifications/$id/read');
  }, 'Đã đánh dấu thông báo đã đọc.');
  Future<void> readAll() => act(() async {
    await repository.send('PUT', '/staff/notifications/read-all');
  }, 'Đã đọc tất cả thông báo.');
}
