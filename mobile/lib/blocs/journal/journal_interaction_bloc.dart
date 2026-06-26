import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../repositories/journal_repository.dart';
import 'journal_interaction_event.dart';
import 'journal_interaction_state.dart';

class JournalInteractionBloc extends Bloc<JournalInteractionEvent, JournalInteractionState> {
  final JournalRepository repository;

  JournalInteractionBloc({required this.repository}) : super(JournalInteractionInitial()) {
    on<ArchiveJournalRequested>(_onArchiveRequested);
    on<DeleteJournalRequested>(_onDeleteRequested);
  }



  Future<void> _onArchiveRequested(ArchiveJournalRequested event, Emitter<JournalInteractionState> emit) async {
    emit(JournalInteractionLoading());
    try {
      final res = await repository.archiveJournal(event.journalId);
      
      if (res.statusCode == 200) {
        emit(JournalArchiveSuccess(res.data['message'] ?? "Jurnal berhasil diarsipkan."));
      } else {
        emit(JournalInteractionFailure(res.data['message'] ?? "Gagal mengarsipkan jurnal."));
      }
    } catch (e) {
      emit(JournalInteractionFailure("Gagal mengarsipkan jurnal: $e"));
    }
  }

  Future<void> _onDeleteRequested(DeleteJournalRequested event, Emitter<JournalInteractionState> emit) async {
    emit(JournalInteractionLoading());
    try {
      final res = await repository.deleteJournal(event.journalId);
      
      if (res.statusCode == 200) {
        emit(JournalDeleteSuccess(res.data['message'] ?? "Jurnal berhasil dihapus."));
      } else {
        emit(JournalInteractionFailure(res.data['message'] ?? "Gagal menghapus jurnal."));
      }
    } catch (e) {
      emit(JournalInteractionFailure("Gagal menghapus jurnal: $e"));
    }
  }
}
