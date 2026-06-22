import 'package:equatable/equatable.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object> get props => [];
}

class ConnectivityRestored extends SyncEvent {}

class ManualSyncTriggered extends SyncEvent {}
