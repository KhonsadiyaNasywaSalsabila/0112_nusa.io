import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_client.dart';
import '../../models/user_model.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(ProfileLoading()) {
    on<ProfileRequested>(_onProfileRequested);
    on<AvatarUpdated>(_onAvatarUpdated);
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
        emit(ProfileLoaded(user, stamps, archives, memories));
      } else {
        emit(const ProfileError("Gagal mengambil data profil atau stempel"));
      }
    } on DioException catch (e) {
      emit(ProfileError(e.response?.data['message'] ?? e.toString()));
    } catch (e) {
      emit(ProfileError(e.toString()));
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
}
