import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_client.dart';
import '../../models/bookmark_model.dart';
import 'bookmark_event.dart';
import 'bookmark_state.dart';

class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  BookmarkBloc() : super(BookmarkLoading()) {
    on<BookmarksRequested>(_onBookmarksRequested);
    on<BookmarkDeleted>(_onBookmarkDeleted);
  }

  Future<void> _onBookmarksRequested(BookmarksRequested event, Emitter<BookmarkState> emit) async {
    emit(BookmarkLoading());
    try {
      final res = await ApiClient.instance.get('/bookmarks');

      if (res.statusCode == 200 && res.data['success']) {
        final List<dynamic> data = res.data['data'];
        
        List<BookmarkModel> planned = [];
        List<BookmarkModel> visited = [];

        for (var item in data) {
          final bookmark = BookmarkModel.fromJson(item as Map<String, dynamic>);
          if (bookmark.status == 'PLANNED') {
            planned.add(bookmark);
          } else {
            visited.add(bookmark);
          }
        }

        emit(BookmarkLoaded(planned, visited));
      } else {
        emit(const BookmarkError("Gagal mengambil data rencana jelajah"));
      }
    } on DioException catch (e) {
      emit(BookmarkError(e.response?.data['message'] ?? e.toString()));
    } catch (e) {
      emit(BookmarkError(e.toString()));
    }
  }

  Future<void> _onBookmarkDeleted(BookmarkDeleted event, Emitter<BookmarkState> emit) async {
    final currentState = state;
    try {
      final res = await ApiClient.instance.delete('/bookmarks/${event.bookmarkId}');

      if (res.statusCode == 200) {
        emit(const BookmarkActionSuccess("Berhasil dihapus dari rencana jelajah"));
        add(BookmarksRequested()); // Reload daftar
      } else {
        emit(const BookmarkActionError("Gagal menghapus rencana jelajah"));
        if (currentState is BookmarkLoaded) emit(currentState);
      }
    } on DioException catch (e) {
      emit(BookmarkActionError(e.response?.data['message'] ?? e.toString()));
      if (currentState is BookmarkLoaded) emit(currentState);
    } catch (e) {
      emit(BookmarkActionError(e.toString()));
      if (currentState is BookmarkLoaded) emit(currentState);
    }
  }
}
