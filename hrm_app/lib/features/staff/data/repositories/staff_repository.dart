import 'package:dio/dio.dart';

typedef StaffItem = Map<String, dynamic>;

List<StaffItem> staffItems(Object? value) => (value as List? ?? [])
    .map((item) => Map<String, dynamic>.from(item as Map))
    .toList();

class StaffRepository {
  final Dio dio;
  StaffRepository(this.dio);

  static String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<StaffItem> workspace(DateTime from, DateTime to) async =>
      Map<String, dynamic>.from(
        await send(
          'GET',
          '/staff/workspace',
          query: {'from': date(from), 'to': date(to)},
        ) as Map,
      );

  Future<StaffItem> options() async => Map<String, dynamic>.from(
    await send('GET', '/staff/request-options') as Map,
  );

  Future<dynamic> send(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final response = await dio.request(
      path,
      data: data,
      queryParameters: query,
      options: Options(method: method),
    );
    final body = response.data;
    if (body is! Map || body['success'] != true) {
      throw Exception(
        body is Map
            ? body['message'] ?? 'Thao tác chưa thành công'
            : 'Phản hồi máy chủ không hợp lệ',
      );
    }
    return body['data'];
  }
}
