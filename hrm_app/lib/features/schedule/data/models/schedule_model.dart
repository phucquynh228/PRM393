import 'package:json_annotation/json_annotation.dart';

part 'schedule_model.g.dart';

@JsonSerializable()
class ScheduleModel {
  @JsonKey(name: 'id') // Based on Spring backend fields, the JSON might have id or scheduleId. Let's map both or just use scheduleId if backend returns it as scheduleId.
  final int? id;

  // As per API spec in request: "scheduleId": 1
  final int? scheduleId;

  final String? shiftName;
  final String? startTime;
  final String? endTime;
  final String? status;

  ScheduleModel({
    this.id,
    this.scheduleId,
    this.shiftName,
    this.startTime,
    this.endTime,
    this.status,
  });

  int get resolvedId => scheduleId ?? id ?? 0;

  factory ScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$ScheduleModelFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleModelToJson(this);
}
