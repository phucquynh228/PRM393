import 'package:dio/dio.dart';

import '../../models/dashboard_summary.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];

class BranchState {
  final Map<String, dynamic> resources;
  final Set<String> loading;
  final Map<String, String> errors;
  const BranchState({
    this.resources = const {},
    this.loading = const {},
    this.errors = const {},
  });
  Map<String, dynamic> get branch => resources['branch'] is Map
      ? Map<String, dynamic>.from(resources['branch'])
      : {};
  List<Map<String, dynamic>> get staff => _maps(branch['staff']);
  List<Map<String, dynamic>> get shifts => _maps(resources['shifts']);
  List<Map<String, dynamic>> get schedules => _maps(resources['schedules']);
  Map<String, dynamic> get attendanceData => resources['attendance'] is Map
      ? Map<String, dynamic>.from(resources['attendance'])
      : {};
  List<Map<String, dynamic>> get attendance =>
      branchAttendanceRecords(attendanceData);
  Map<String, dynamic> get report => resources['report'] is Map
      ? Map<String, dynamic>.from(resources['report'])
      : {};
}

class BranchCubit extends Cubit<BranchState> {
  final Dio dio;
  final Set<String> _mutations = {};
  final Map<String, int> _versions = {};
  BranchCubit(this.dio) : super(const BranchState());
  Future<void> fetch(
    String name,
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final version = (_versions[name] ?? 0) + 1;
    _versions[name] = version;
    emit(
      BranchState(
        resources: state.resources,
        loading: {...state.loading, name},
        errors: {...state.errors}..remove(name),
      ),
    );
    try {
      final response = await dio.get(path, queryParameters: query);
      final body = response.data as Map;
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Không tải được dữ liệu');
      }
      if (!isClosed && _versions[name] == version) {
        emit(
          BranchState(
            resources: {...state.resources, name: body['data']},
            loading: {...state.loading}..remove(name),
            errors: state.errors,
          ),
        );
      }
    } catch (e) {
      if (!isClosed && _versions[name] == version) {
        emit(
          BranchState(
            resources: state.resources,
            loading: {...state.loading}..remove(name),
            errors: {...state.errors, name: cleanError(e)},
          ),
        );
      }
    }
  }

  Future<void> send(String method, String path, {Object? data}) async {
    final key = '$method $path';
    if (!_mutations.add(key)) {
      throw Exception('Thao tác đang được xử lý. Vui lòng chờ.');
    }
    try {
      final response = await dio.request(
        path,
        data: data,
        options: Options(method: method),
      );
      final body = response.data as Map;
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Không thực hiện được thao tác');
      }
    } on DioException catch (e) {
      throw Exception(cleanError(e));
    } finally {
      _mutations.remove(key);
    }
  }

  static String cleanError(dynamic error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
      return 'Chưa kết nối được máy chủ. Vui lòng thử lại.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
