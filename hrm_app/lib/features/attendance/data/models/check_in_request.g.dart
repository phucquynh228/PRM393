// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CheckInRequest _$CheckInRequestFromJson(Map<String, dynamic> json) =>
    CheckInRequest(
      scheduleId: (json['scheduleId'] as num?)?.toInt(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );

Map<String, dynamic> _$CheckInRequestToJson(CheckInRequest instance) =>
    <String, dynamic>{
      'scheduleId': instance.scheduleId,
      'lat': instance.lat,
      'lng': instance.lng,
    };
