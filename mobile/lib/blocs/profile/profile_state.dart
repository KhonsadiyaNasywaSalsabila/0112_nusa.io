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
  final bool hasMoreArchives;
  final bool hasMoreMemories;
  final int archivePage;
  final int memoryPage;
  final String? currentMemoryTheme;
  final String? currentMemorySearch;
  final String? currentArchiveTheme;
  final String? currentArchiveSearch;
  final String? currentStampSearch;

  const ProfileLoaded(
    this.user, 
    this.stamps, 
    this.archives, 
    this.memories, {
    this.hasMoreArchives = false,
    this.hasMoreMemories = false,
    this.archivePage = 1,
    this.memoryPage = 1,
    this.currentMemoryTheme,
    this.currentMemorySearch,
    this.currentArchiveTheme,
    this.currentArchiveSearch,
    this.currentStampSearch,
  });

  ProfileLoaded copyWith({
    UserModel? user,
    List<dynamic>? stamps,
    List<dynamic>? archives,
    List<dynamic>? memories,
    bool? hasMoreArchives,
    bool? hasMoreMemories,
    int? archivePage,
    int? memoryPage,
    String? currentMemoryTheme,
    String? currentMemorySearch,
    String? currentArchiveTheme,
    String? currentArchiveSearch,
    String? currentStampSearch,
  }) {
    return ProfileLoaded(
      user ?? this.user,
      stamps ?? this.stamps,
      archives ?? this.archives,
      memories ?? this.memories,
      hasMoreArchives: hasMoreArchives ?? this.hasMoreArchives,
      hasMoreMemories: hasMoreMemories ?? this.hasMoreMemories,
      archivePage: archivePage ?? this.archivePage,
      memoryPage: memoryPage ?? this.memoryPage,
      currentMemoryTheme: currentMemoryTheme ?? this.currentMemoryTheme,
      currentMemorySearch: currentMemorySearch ?? this.currentMemorySearch,
      currentArchiveTheme: currentArchiveTheme ?? this.currentArchiveTheme,
      currentArchiveSearch: currentArchiveSearch ?? this.currentArchiveSearch,
      currentStampSearch: currentStampSearch ?? this.currentStampSearch,
    );
  }

  @override
  List<Object> get props => [
        user, stamps, archives, memories,
        hasMoreArchives, hasMoreMemories, archivePage, memoryPage,
        currentMemoryTheme ?? '', currentMemorySearch ?? '',
        currentArchiveTheme ?? '', currentArchiveSearch ?? '',
        currentStampSearch ?? ''
      ];
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

class ProfileActionSuccess extends ProfileState {
  final String message;
  const ProfileActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

class ProfileActionError extends ProfileState {
  final String error;
  const ProfileActionError(this.error);
  @override
  List<Object> get props => [error];
}

