import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object> get props => [];
}

class ProfileRequested extends ProfileEvent {}

class LoadMoreMemoriesRequested extends ProfileEvent {}

class LoadMoreArchivesRequested extends ProfileEvent {}

class AvatarUpdated extends ProfileEvent {
  final String imagePath;
  const AvatarUpdated(this.imagePath);

  @override
  List<Object> get props => [imagePath];
}

class FilterMemoriesRequested extends ProfileEvent {
  final String? theme;
  final String? search;
  const FilterMemoriesRequested({this.theme, this.search});

  @override
  List<Object> get props => [theme ?? '', search ?? ''];
}

class FilterArchivesRequested extends ProfileEvent {
  final String? theme;
  final String? search;
  const FilterArchivesRequested({this.theme, this.search});

  @override
  List<Object> get props => [theme ?? '', search ?? ''];
}

class FilterStampsRequested extends ProfileEvent {
  final String search;
  const FilterStampsRequested(this.search);

  @override
  List<Object> get props => [search];
}

class ProfileUpdateRequested extends ProfileEvent {
  final String username;
  final String bio;
  const ProfileUpdateRequested({required this.username, required this.bio});

  @override
  List<Object> get props => [username, bio];
}

class PasswordUpdateRequested extends ProfileEvent {
  final String oldPassword;
  final String newPassword;
  const PasswordUpdateRequested({required this.oldPassword, required this.newPassword});

  @override
  List<Object> get props => [oldPassword, newPassword];
}

class AccountDeleteRequested extends ProfileEvent {}

