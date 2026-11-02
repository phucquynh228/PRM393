import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

class LoadSchedules extends HomeEvent {}

class CheckInRequested extends HomeEvent {
  final int? scheduleId;
  const CheckInRequested({this.scheduleId});

  @override
  List<Object> get props => [scheduleId ?? -1];
}

class CheckOutRequested extends HomeEvent {
  final int attendanceId;
  const CheckOutRequested({required this.attendanceId});

  @override
  List<Object> get props => [attendanceId];
}
