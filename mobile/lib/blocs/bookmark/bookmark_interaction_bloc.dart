import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../repositories/bookmark_repository.dart';

abstract class BookmarkEvent {}

class BookmarkLocationRequested extends BookmarkEvent {
  final String locationId;
  BookmarkLocationRequested(this.locationId);
}

class SaveJournalRequested extends BookmarkEvent {
  final String journalId;
  SaveJournalRequested(this.journalId);
}

class UnbookmarkLocationRequested extends BookmarkEvent {
  final String locationId;
  UnbookmarkLocationRequested(this.locationId);
}

class UnsaveJournalRequested extends BookmarkEvent {
  final String journalId;
  UnsaveJournalRequested(this.journalId);
}

abstract class BookmarkState {}

class BookmarkInitial extends BookmarkState {}

class BookmarkLoading extends BookmarkState {}

class BookmarkSuccess extends BookmarkState {
  final String message;
  BookmarkSuccess(this.message);
}

class BookmarkFailure extends BookmarkState {
  final String error;
  BookmarkFailure(this.error);
}

class BookmarkInteractionBloc extends Bloc<BookmarkEvent, BookmarkState> {
  final BookmarkRepository repository;

  BookmarkInteractionBloc({required this.repository}) : super(BookmarkInitial()) {
    on<BookmarkLocationRequested>(_onBookmarkLocation);
    on<SaveJournalRequested>(_onSaveJournal);
    on<UnbookmarkLocationRequested>(_onUnbookmarkLocation);
    on<UnsaveJournalRequested>(_onUnsaveJournal);
  }

  Future<void> _onBookmarkLocation(BookmarkLocationRequested event, Emitter<BookmarkState> emit) async {
    emit(BookmarkLoading());
    try {
      final res = await repository.bookmarkLocation(event.locationId);
      if (res.statusCode == 201) {
        emit(BookmarkSuccess(res.data['message'] ?? "Berhasil disimpan ke Rencana Jelajah!"));
      } else {
        emit(BookmarkFailure(res.data['message'] ?? "Gagal menyimpan rencana jelajah."));
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? "Gagal menyimpan jejak.";
      emit(BookmarkFailure(msg));
    } catch (e) {
      emit(BookmarkFailure("Terjadi kesalahan: $e"));
    }
  }

  Future<void> _onSaveJournal(SaveJournalRequested event, Emitter<BookmarkState> emit) async {
    emit(BookmarkLoading());
    try {
      final res = await repository.saveJournal(event.journalId);
      if (res.statusCode == 201) {
        emit(BookmarkSuccess(res.data['message'] ?? "Jurnal berhasil disimpan ke Koleksi!"));
      } else {
        emit(BookmarkFailure(res.data['message'] ?? "Gagal menyimpan jurnal."));
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? "Gagal menyimpan jurnal.";
      emit(BookmarkFailure(msg));
    } catch (e) {
      emit(BookmarkFailure("Terjadi kesalahan: $e"));
    }
  }

  Future<void> _onUnbookmarkLocation(UnbookmarkLocationRequested event, Emitter<BookmarkState> emit) async {
    emit(BookmarkLoading());
    try {
      final res = await repository.removeBookmarkedLocationByLocationId(event.locationId);
      if (res.statusCode == 200) {
        emit(BookmarkSuccess(res.data['message'] ?? "Lokasi dihapus dari rencana jelajah."));
      } else {
        emit(BookmarkFailure(res.data['message'] ?? "Gagal menghapus rencana jelajah."));
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? "Gagal menghapus jejak.";
      emit(BookmarkFailure(msg));
    } catch (e) {
      emit(BookmarkFailure("Terjadi kesalahan: $e"));
    }
  }

  Future<void> _onUnsaveJournal(UnsaveJournalRequested event, Emitter<BookmarkState> emit) async {
    emit(BookmarkLoading());
    try {
      final res = await repository.unsaveJournalByJournalId(event.journalId);
      if (res.statusCode == 200) {
        emit(BookmarkSuccess(res.data['message'] ?? "Jurnal dihapus dari koleksi."));
      } else {
        emit(BookmarkFailure(res.data['message'] ?? "Gagal menghapus jurnal dari koleksi."));
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? "Gagal menghapus jurnal.";
      emit(BookmarkFailure(msg));
    } catch (e) {
      emit(BookmarkFailure("Terjadi kesalahan: $e"));
    }
  }
}
