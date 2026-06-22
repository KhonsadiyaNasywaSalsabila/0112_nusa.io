import 'package:equatable/equatable.dart';

import '../../models/bookmark_model.dart';

abstract class BookmarkState extends Equatable {
  const BookmarkState();
  
  @override
  List<Object> get props => [];
}

class BookmarkLoading extends BookmarkState {}

class BookmarkLoaded extends BookmarkState {
  final List<BookmarkModel> planned;
  final List<BookmarkModel> visited;

  const BookmarkLoaded(this.planned, this.visited);

  @override
  List<Object> get props => [planned, visited];
}

class BookmarkError extends BookmarkState {
  final String error;
  const BookmarkError(this.error);

  @override
  List<Object> get props => [error];
}

class BookmarkActionSuccess extends BookmarkState {
  final String message;
  const BookmarkActionSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class BookmarkActionError extends BookmarkState {
  final String error;
  const BookmarkActionError(this.error);

  @override
  List<Object> get props => [error];
}
