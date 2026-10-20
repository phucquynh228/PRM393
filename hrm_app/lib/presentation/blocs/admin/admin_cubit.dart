import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_error.dart';

import '../../../data/models/api_response.dart';
import '../../../data/remote/api_client.dart';

class AdminState {
  final Map<String, dynamic>? dashboard;
  final List<dynamic> stores, users, attendance;
  final bool loading, initialized;
  final String? error;
  const AdminState({
    this.dashboard,
    this.stores = const [],
    this.users = const [],
    this.attendance = const [],
    this.loading = false,
    this.initialized = false,
    this.error,
  });
}

class AdminCubit extends Cubit<AdminState> {
  final ApiClient api;
  AdminCubit(this.api) : super(const AdminState());
  Future<void> load() async {
    if (isClosed || state.loading) return;
    emit(
      AdminState(
        dashboard: state.dashboard,
        stores: state.stores,
        users: state.users,
        attendance: state.attendance,
        loading: true,
        initialized: state.initialized,
      ),
    );
    try {
      final data = await Future.wait([
        api.getDashboardSummary(),
        api.getAllStores(),
        api.getAllUsers(),
        api.getAllAttendance(),
      ]);
      for (final response in data) {
        if (response.success != true) {
          throw Exception(response.message ?? 'Không tải được dữ liệu');
        }
      }
      if (!isClosed) {
        emit(
          AdminState(
            dashboard: Map<String, dynamic>.from(data[0].data as Map),
            stores: data[1].data as List,
            users: data[2].data as List,
            attendance: data[3].data as List,
            initialized: true,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          AdminState(
            dashboard: state.dashboard,
            stores: state.stores,
            users: state.users,
            attendance: state.attendance,
            initialized: state.initialized,
            error: readableApiError(e),
          ),
        );
      }
    }
  }

  Future<void> save(Future<ApiResponse<dynamic>> Function() action) async {
    final result = await action();
    if (result.success != true) {
      throw Exception(result.message ?? 'Không lưu được dữ liệu');
    }
    await load();
  }
}
