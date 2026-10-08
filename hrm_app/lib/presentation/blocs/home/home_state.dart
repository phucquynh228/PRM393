import 'package:equatable/equatable.dart';
import '../../../data/models/schedule_model.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<ScheduleModel> schedules;
  const HomeLoaded({required this.schedules});

  @override
  List<Object> get props => [schedules];
}

class HomeActionSuccess extends HomeState {
  final String message;
  const HomeActionSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

class HomeError extends HomeState {
  final String error;
  const HomeError({required this.error});

  @override
  List<Object> get props => [error];
}
