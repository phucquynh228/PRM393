import 'package:json_annotation/json_annotation.dart';

part 'check_in_request.g.dart';

@JsonSerializable()
class CheckInRequest {
  final int? scheduleId;
  final double lat;
  final double lng;

  CheckInRequest({
    this.scheduleId,
    required this.lat,
    required this.lng,
  });

  factory CheckInRequest.fromJson(Map<String, dynamic> json) =>
      _$CheckInRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CheckInRequestToJson(this);
}
