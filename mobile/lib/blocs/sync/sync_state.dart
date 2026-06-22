import 'package:equatable/equatable.dart';

abstract class SyncState extends Equatable {
  const SyncState();
  
  @override
  List<Object> get props => [];
}

class SyncIdle extends SyncState {}

class SyncInProgress extends SyncState {
  final int count;
  const SyncInProgress(this.count);

  @override
  List<Object> get props => [count];
}

class SyncCompleted extends SyncState {}

class SyncFailed extends SyncState {
  final String error;
  const SyncFailed(this.error);

  @override
  List<Object> get props => [error];
}
