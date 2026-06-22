import 'package:equatable/equatable.dart';

abstract class JournalInteractionEvent extends Equatable {
  const JournalInteractionEvent();

  @override
  List<Object> get props => [];
}


class BookmarkJournalRequested extends JournalInteractionEvent {
  final String journalId;
  const BookmarkJournalRequested(this.journalId);

  @override
  List<Object> get props => [journalId];
}

class ArchiveJournalRequested extends JournalInteractionEvent {
  final String journalId;
  const ArchiveJournalRequested(this.journalId);

  @override
  List<Object> get props => [journalId];
}

class DeleteJournalRequested extends JournalInteractionEvent {
  final String journalId;
  const DeleteJournalRequested(this.journalId);

  @override
  List<Object> get props => [journalId];
}
