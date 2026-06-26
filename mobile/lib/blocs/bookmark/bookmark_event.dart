import 'package:equatable/equatable.dart';

abstract class BookmarkEvent extends Equatable {
  const BookmarkEvent();

  @override
  List<Object> get props => [];
}

class BookmarksRequested extends BookmarkEvent {}

class FilterBookmarksRequested extends BookmarkEvent {
  final String? search;
  const FilterBookmarksRequested({this.search});

  @override
  List<Object> get props => [search ?? ''];
}

class LoadMoreBookmarksRequested extends BookmarkEvent {}

class BookmarkDeleted extends BookmarkEvent {
  final String bookmarkId;
  const BookmarkDeleted(this.bookmarkId);

  @override
  List<Object> get props => [bookmarkId];
}
