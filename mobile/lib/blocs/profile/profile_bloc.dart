import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_client.dart';
import '../../models/user_model.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(ProfileLoading()) {
    on<ProfileRequested>(_onProfileRequested);
    on<LoadMoreMemoriesRequested>(_onLoadMoreMemories);
    on<LoadMoreArchivesRequested>(_onLoadMoreArchives);
    on<AvatarUpdated>(_onAvatarUpdated);
    on<FilterMemoriesRequested>(_onFilterMemories);
    on<FilterArchivesRequested>(_onFilterArchives);
    on<FilterStampsRequested>(_onFilterStamps);
    on<ProfileUpdateRequested>(_onProfileUpdate);
    on<PasswordUpdateRequested>(_onPasswordUpdate);
    on<AccountDeleteRequested>(_onAccountDelete);
  }

  Future<void> _onProfileRequested(ProfileRequested event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final responses = await Future.wait([
        ApiClient.instance.get('/auth/me'),
        ApiClient.instance.get('/users/me/stamps'),
        ApiClient.instance.get('/users/me/archives'),
        ApiClient.instance.get('/users/me/memories'),
      ]);

      final userRes = responses[0];
      final stampsRes = responses[1];
      final archivesRes = responses[2];
      final memoriesRes = responses[3];

      if (userRes.statusCode == 200 && stampsRes.statusCode == 200 && archivesRes.statusCode == 200 && memoriesRes.statusCode == 200) {
        final user = UserModel.fromJson(userRes.data['data']);
        final stamps = stampsRes.data['data'];
        final archives = archivesRes.data['data'];
        final memories = memoriesRes.data['data'];
        
        final hasMoreArchives = archivesRes.data['meta']?['hasNextPage'] ?? false;
        final hasMoreMemories = memoriesRes.data['meta']?['hasNextPage'] ?? false;

        emit(ProfileLoaded(
          user, stamps, archives, memories,
          hasMoreArchives: hasMoreArchives,
          hasMoreMemories: hasMoreMemories,
          archivePage: 1,
          memoryPage: 1,
        ));
      } else {
        emit(const ProfileError("Gagal mengambil data profil atau stempel"));
      }
    } on DioException catch (e) {
      emit(ProfileError(e.response?.data['message'] ?? e.toString()));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onLoadMoreMemories(LoadMoreMemoriesRequested event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is ProfileLoaded && currentState.hasMoreMemories) {
      try {
        final nextPage = currentState.memoryPage + 1;
        String url = '/users/me/memories?page=$nextPage&limit=5';
        if (currentState.currentMemoryTheme != null && currentState.currentMemoryTheme != 'Semua') {
          url += '&theme=${currentState.currentMemoryTheme}';
        }
        if (currentState.currentMemorySearch != null && currentState.currentMemorySearch!.isNotEmpty) {
          url += '&search=${currentState.currentMemorySearch}';
        }
        
        final res = await ApiClient.instance.get(url);
        if (res.statusCode == 200) {
          final newMemories = res.data['data'];
          final hasMore = res.data['meta']?['hasNextPage'] ?? false;
          emit(currentState.copyWith(
            memories: [...currentState.memories, ...newMemories],
            memoryPage: nextPage,
            hasMoreMemories: hasMore,
          ));
        }
      } catch (_) {}
    }
  }

  Future<void> _onLoadMoreArchives(LoadMoreArchivesRequested event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is ProfileLoaded && currentState.hasMoreArchives) {
      try {
        final nextPage = currentState.archivePage + 1;
        String url = '/users/me/archives?page=$nextPage&limit=5';
        if (currentState.currentArchiveTheme != null && currentState.currentArchiveTheme != 'Semua') {
          url += '&theme=${currentState.currentArchiveTheme}';
        }
        if (currentState.currentArchiveSearch != null && currentState.currentArchiveSearch!.isNotEmpty) {
          url += '&search=${currentState.currentArchiveSearch}';
        }

        final res = await ApiClient.instance.get(url);
        if (res.statusCode == 200) {
          final newArchives = res.data['data'];
          final hasMore = res.data['meta']?['hasNextPage'] ?? false;
          emit(currentState.copyWith(
            archives: [...currentState.archives, ...newArchives],
            archivePage: nextPage,
            hasMoreArchives: hasMore,
          ));
        }
      } catch (_) {}
    }
  }

  Future<void> _onFilterMemories(FilterMemoriesRequested event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      try {
        String url = '/users/me/memories?page=1&limit=5';
        if (event.theme != null && event.theme != 'Semua') {
          url += '&theme=${event.theme}';
        }
        if (event.search != null && event.search!.isNotEmpty) {
          url += '&search=${event.search}';
        }

        final res = await ApiClient.instance.get(url);
        if (res.statusCode == 200) {
          final newMemories = res.data['data'];
          final hasMore = res.data['meta']?['hasNextPage'] ?? false;
          emit(currentState.copyWith(
            memories: newMemories,
            memoryPage: 1,
            hasMoreMemories: hasMore,
            currentMemoryTheme: event.theme,
            currentMemorySearch: event.search,
          ));
        }
      } catch (_) {}
    }
  }

  Future<void> _onFilterArchives(FilterArchivesRequested event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      try {
        String url = '/users/me/archives?page=1&limit=5';
        if (event.theme != null && event.theme != 'Semua') {
          url += '&theme=${event.theme}';
        }
        if (event.search != null && event.search!.isNotEmpty) {
          url += '&search=${event.search}';
        }

        final res = await ApiClient.instance.get(url);
        if (res.statusCode == 200) {
          final newArchives = res.data['data'];
          final hasMore = res.data['meta']?['hasNextPage'] ?? false;
          emit(currentState.copyWith(
            archives: newArchives,
            archivePage: 1,
            hasMoreArchives: hasMore,
            currentArchiveTheme: event.theme,
            currentArchiveSearch: event.search,
          ));
        }
      } catch (_) {}
    }
  }

  Future<void> _onAvatarUpdated(AvatarUpdated event, Emitter<ProfileState> emit) async {
    final currentState = state;
    try {
      FormData formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(event.imagePath),
      });

      final res = await ApiClient.instance.patch('/auth/me/avatar', data: formData);

      if (res.statusCode == 200) {
        emit(const AvatarUpdateSuccess("Avatar berhasil diperbarui"));
        add(ProfileRequested());
      } else {
        emit(const AvatarUpdateFailed("Gagal memperbarui avatar"));
        if (currentState is ProfileLoaded) emit(currentState);
      }
    } on DioException catch (e) {
      emit(AvatarUpdateFailed(e.response?.data['message'] ?? e.toString()));
      if (currentState is ProfileLoaded) emit(currentState);
    } catch (e) {
      emit(AvatarUpdateFailed(e.toString()));
      if (currentState is ProfileLoaded) emit(currentState);
    }
  }

  Future<void> _onFilterStamps(FilterStampsRequested event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      try {
        String url = '/users/me/stamps';
        if (event.search.isNotEmpty) {
          url += '?search=${event.search}';
        }
        final res = await ApiClient.instance.get(url);
        if (res.statusCode == 200) {
          emit(currentState.copyWith(
            stamps: res.data['data'],
            currentStampSearch: event.search,
          ));
        }
      } catch (_) {}
    }
  }

  Future<void> _onProfileUpdate(ProfileUpdateRequested event, Emitter<ProfileState> emit) async {
    final currentState = state;
    try {
      final res = await ApiClient.instance.put('/auth/me/profile', data: {
        'username': event.username,
        'bio': event.bio,
      });

      if (res.statusCode == 200) {
        emit(const ProfileActionSuccess("Profil berhasil diperbarui"));
        add(ProfileRequested());
      } else {
        emit(const ProfileActionError("Gagal memperbarui profil"));
        if (currentState is ProfileLoaded) emit(currentState);
      }
    } on DioException catch (e) {
      emit(ProfileActionError(e.response?.data['message'] ?? e.toString()));
      if (currentState is ProfileLoaded) emit(currentState);
    } catch (e) {
      emit(ProfileActionError(e.toString()));
      if (currentState is ProfileLoaded) emit(currentState);
    }
  }

  Future<void> _onPasswordUpdate(PasswordUpdateRequested event, Emitter<ProfileState> emit) async {
    final currentState = state;
    try {
      final res = await ApiClient.instance.put('/auth/me/password', data: {
        'oldPassword': event.oldPassword,
        'newPassword': event.newPassword,
      });

      if (res.statusCode == 200) {
        emit(const ProfileActionSuccess("Kata sandi berhasil diperbarui"));
        if (currentState is ProfileLoaded) emit(currentState);
      } else {
        emit(const ProfileActionError("Gagal memperbarui kata sandi"));
        if (currentState is ProfileLoaded) emit(currentState);
      }
    } on DioException catch (e) {
      emit(ProfileActionError(e.response?.data['message'] ?? e.toString()));
      if (currentState is ProfileLoaded) emit(currentState);
    } catch (e) {
      emit(ProfileActionError(e.toString()));
      if (currentState is ProfileLoaded) emit(currentState);
    }
  }

  Future<void> _onAccountDelete(AccountDeleteRequested event, Emitter<ProfileState> emit) async {
    try {
      final res = await ApiClient.instance.delete('/auth/me/account');
      if (res.statusCode == 200) {
        emit(const ProfileActionSuccess("Akun berhasil dihapus. Sampai jumpa kembali!"));
      } else {
        emit(const ProfileActionError("Gagal menghapus akun"));
      }
    } on DioException catch (e) {
      emit(ProfileActionError(e.response?.data['message'] ?? e.toString()));
    } catch (e) {
      emit(ProfileActionError(e.toString()));
    }
  }
}
