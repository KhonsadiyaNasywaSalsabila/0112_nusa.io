import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object> get props => [];
}

class ProfileRequested extends ProfileEvent {}

class AvatarUpdated extends ProfileEvent {
  final String imagePath;
  const AvatarUpdated(this.imagePath);

  @override
  List<Object> get props => [imagePath];
}
