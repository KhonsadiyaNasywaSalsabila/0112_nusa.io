import 'package:equatable/equatable.dart';

abstract class DraftEvent extends Equatable {
  const DraftEvent();

  @override
  List<Object> get props => [];
}

class DraftsRequested extends DraftEvent {}

class PublishPressed extends DraftEvent {
  final String journalId;
  const PublishPressed(this.journalId);

  @override
  List<Object> get props => [journalId];
}
