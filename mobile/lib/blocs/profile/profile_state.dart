import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
  
  @override
  List<Object> get props => [];
}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserModel user;
  final List<dynamic> stamps;
  final List<dynamic> archives;
  final List<dynamic> memories;

  const ProfileLoaded(this.user, this.stamps, this.archives, this.memories);

  @override
  List<Object> get props => [user, stamps, archives, memories];
}

class ProfileError extends ProfileState {
  final String error;
  const ProfileError(this.error);

  @override
  List<Object> get props => [error];
}

class AvatarUpdateSuccess extends ProfileState {
  final String message;
  const AvatarUpdateSuccess(this.message);
  @override
  List<Object> get props => [message];
}

class AvatarUpdateFailed extends ProfileState {
  final String error;
  const AvatarUpdateFailed(this.error);
  @override
  List<Object> get props => [error];
}
