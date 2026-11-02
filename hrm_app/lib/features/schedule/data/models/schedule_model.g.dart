// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScheduleModel _$ScheduleModelFromJson(Map<String, dynamic> json) =>
    ScheduleModel(
      id: (json['id'] as num?)?.toInt(),
      scheduleId: (json['scheduleId'] as num?)?.toInt(),
      shiftName: json['shiftName'] as String?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$ScheduleModelToJson(ScheduleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'scheduleId': instance.scheduleId,
      'shiftName': instance.shiftName,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'status': instance.status,
    };
