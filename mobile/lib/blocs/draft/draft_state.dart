import 'package:equatable/equatable.dart';
import '../../models/journal_model.dart';

abstract class DraftState extends Equatable {
  const DraftState();
  
  @override
  List<Object> get props => [];
}

class DraftLoading extends DraftState {}

class DraftsLoaded extends DraftState {
  final List<JournalModel> combinedDrafts;

  const DraftsLoaded(this.combinedDrafts);

  @override
  List<Object> get props => [combinedDrafts];
}

class DraftError extends DraftState {
  final String error;
  const DraftError(this.error);

  @override
  List<Object> get props => [error];
}

// State khusus untuk menangani aksi Publish (berhasil atau gagal) tanpa merusak tampilan list
class DraftPublishSuccess extends DraftState {
  final String message;
  const DraftPublishSuccess(this.message);
  @override
  List<Object> get props => [message];
}

class DraftPublishFailed extends DraftState {
  final String error;
  const DraftPublishFailed(this.error);
  @override
  List<Object> get props => [error];
}
