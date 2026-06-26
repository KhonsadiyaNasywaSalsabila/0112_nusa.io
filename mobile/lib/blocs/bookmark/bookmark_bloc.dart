import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_client.dart';
import '../../models/bookmark_model.dart';
import 'bookmark_event.dart';
import 'bookmark_state.dart';

class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  BookmarkBloc() : super(BookmarkLoading()) {
    on<BookmarksRequested>(_onBookmarksRequested);
    on<FilterBookmarksRequested>(_onFilterBookmarksRequested);
    on<LoadMoreBookmarksRequested>(_onLoadMoreBookmarksRequested);
    on<BookmarkDeleted>(_onBookmarkDeleted);
  }

  Future<void> _onBookmarksRequested(BookmarksRequested event, Emitter<BookmarkState> emit) async {
    emit(BookmarkLoading());
    try {
      final res = await ApiClient.instance.get('/bookmarks/locations');

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

        final hasMore = res.data['meta']?['hasNextPage'] ?? false;

        emit(BookmarkLoaded(planned, visited, hasMore: hasMore, page: 1));
      } else {
        emit(const BookmarkError("Gagal mengambil data rencana jelajah"));
      }
    } on DioException catch (e) {
      emit(BookmarkError(e.response?.data['message'] ?? e.toString()));
    } catch (e) {
      emit(BookmarkError(e.toString()));
    }
  }

  Future<void> _onFilterBookmarksRequested(FilterBookmarksRequested event, Emitter<BookmarkState> emit) async {
    emit(BookmarkLoading());
    try {
      String url = '/bookmarks/locations?page=1&limit=10';
      if (event.search != null && event.search!.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(event.search!)}';
      }
      final res = await ApiClient.instance.get(url);

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

        final hasMore = res.data['meta']?['hasNextPage'] ?? false;

        emit(BookmarkLoaded(planned, visited, hasMore: hasMore, page: 1, searchQuery: event.search));
      } else {
        emit(const BookmarkError("Gagal memfilter rencana jelajah"));
      }
    } on DioException catch (e) {
      emit(BookmarkError(e.response?.data['message'] ?? e.toString()));
    } catch (e) {
      emit(BookmarkError(e.toString()));
    }
  }

  Future<void> _onLoadMoreBookmarksRequested(LoadMoreBookmarksRequested event, Emitter<BookmarkState> emit) async {
    final currentState = state;
    if (currentState is BookmarkLoaded && currentState.hasMore) {
      try {
        final nextPage = currentState.page + 1;
        String url = '/bookmarks/locations?page=$nextPage&limit=10';
        if (currentState.searchQuery != null && currentState.searchQuery!.isNotEmpty) {
          url += '&search=${Uri.encodeComponent(currentState.searchQuery!)}';
        }
        final res = await ApiClient.instance.get(url);

        if (res.statusCode == 200 && res.data['success']) {
          final List<dynamic> data = res.data['data'];
          final hasMore = res.data['meta']?['hasNextPage'] ?? false;
          
          List<BookmarkModel> newPlanned = [];
          List<BookmarkModel> newVisited = [];

          for (var item in data) {
            final bookmark = BookmarkModel.fromJson(item as Map<String, dynamic>);
            if (bookmark.status == 'PLANNED') {
              newPlanned.add(bookmark);
            } else {
              newVisited.add(bookmark);
            }
          }

          emit(currentState.copyWith(
            planned: [...currentState.planned, ...newPlanned],
            visited: [...currentState.visited, ...newVisited],
            page: nextPage,
            hasMore: hasMore,
          ));
        }
      } catch (_) {}
    }
  }


  Future<void> _onBookmarkDeleted(BookmarkDeleted event, Emitter<BookmarkState> emit) async {
    final currentState = state;
    try {
      final res = await ApiClient.instance.delete('/bookmarks/locations/${event.bookmarkId}');

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
