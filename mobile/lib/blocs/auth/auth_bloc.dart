import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../services/api_client.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _storage = const FlutterSecureStorage();
  final _dio = ApiClient.instance;

  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckStatus);
    on<LoginRequested>(_onLogin);
    on<RegisterRequested>(_onRegister);
    on<LogoutRequested>(_onLogout);
    on<ContinueAsGuest>(_onGuestMode);
  }

  Future<void> _onCheckStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    // Beri waktu 2.5 detik untuk memutar animasi POV Journey di Splash Screen
    await Future.delayed(const Duration(milliseconds: 2500));
    
    final token = await _storage.read(key: 'jwt_token');
    final userId = await _storage.read(key: 'user_id');
    if (token != null && userId != null) {
      emit(AuthAuthenticated(userId));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': event.email,
        'password': event.password,
      });
      
      final token = response.data['token'];
      final userId = response.data['data']['id'];
      await _storage.write(key: 'jwt_token', value: token);
      await _storage.write(key: 'user_id', value: userId);
      emit(AuthAuthenticated(userId));
    } on DioException catch (e) {
      // SANGAT BERSIH! Memanfaatkan pesan global dari ApiClient
      emit(AuthError(e.message ?? 'Koneksi gagal.'));
    } catch (_) {
      emit(const AuthError('Terjadi kesalahan sistem.'));
    }
  }

  Future<void> _onRegister(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _dio.post('/auth/register', data: {
        'username': event.username,
        'email': event.email,
        'password': event.password,
      });
      emit(AuthRegisterSuccess());
    } on DioException catch (e) {
      // SANGAT BERSIH! Memanfaatkan pesan global dari ApiClient
      emit(AuthError(e.message ?? 'Gagal mendaftar.'));
    } catch (_) {
      emit(const AuthError('Terjadi kesalahan sistem.'));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
    emit(AuthUnauthenticated());
  }

  Future<void> _onGuestMode(ContinueAsGuest event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    // Beri sedikit jeda agar transisi UI terlihat halus
    await Future.delayed(const Duration(milliseconds: 500)); 
    emit(AuthGuestMode());
  }
}