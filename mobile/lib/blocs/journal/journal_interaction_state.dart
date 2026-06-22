import 'package:equatable/equatable.dart';

abstract class JournalInteractionState extends Equatable {
  const JournalInteractionState();
  
  @override
  List<Object> get props => [];
}

class JournalInteractionInitial extends JournalInteractionState {}

class JournalInteractionLoading extends JournalInteractionState {}

class JournalBookmarkSuccess extends JournalInteractionState {
  final String message;
  const JournalBookmarkSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class JournalArchiveSuccess extends JournalInteractionState {
  final String message;
  const JournalArchiveSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class JournalDeleteSuccess extends JournalInteractionState {
  final String message;
  const JournalDeleteSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class JournalInteractionFailure extends JournalInteractionState {
  final String message;
  const JournalInteractionFailure(this.message);

  @override
  List<Object> get props => [message];
}
