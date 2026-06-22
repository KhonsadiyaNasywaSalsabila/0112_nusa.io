import 'package:equatable/equatable.dart';

abstract class BookmarkEvent extends Equatable {
  const BookmarkEvent();

  @override
  List<Object> get props => [];
}

class BookmarksRequested extends BookmarkEvent {}

class BookmarkDeleted extends BookmarkEvent {
  final String bookmarkId;
  const BookmarkDeleted(this.bookmarkId);

  @override
  List<Object> get props => [bookmarkId];
}
