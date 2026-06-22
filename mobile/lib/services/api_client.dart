import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:3000/api/v1', // IP Loopback standar Emulator Android ke localhost
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Dio get instance {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // =========================================================
          // JARING PENANGKAP ERROR GLOBAL (MENCEGAH CRASH HTML)
          // =========================================================
          String customMessage = 'Terjadi kesalahan tidak terduga pada server.';

          if (e.response != null) {
            final data = e.response?.data;
            
            // 1. Jika respons adalah JSON yang valid dari backend kita
            if (data is Map<String, dynamic> && data['message'] != null) {
              customMessage = data['message'];
            } 
            // 2. Jika respons adalah HTML/Teks karena salah URL (404)
            else if (e.response?.statusCode == 404) {
              customMessage = 'Endpoint API tidak ditemukan (404).';
            } 
            // 3. Jika respons adalah HTML karena Server Crash (500+)
            else if (e.response?.statusCode != null && e.response!.statusCode! >= 500) {
              customMessage = 'Peladen sedang bermasalah atau mati (500).';
            } 
            // 4. Format lain yang tidak dikenali
            else {
              customMessage = 'Respons peladen tidak valid (Bukan JSON).';
            }
          } else {
            // Jika server mati total atau tidak ada koneksi internet
            customMessage = 'Gagal terhubung ke peladen. Periksa koneksi Anda.';
          }

          // Kita modifikasi DioException-nya dengan pesan yang sudah bersih & aman
          final modifiedError = e.copyWith(message: customMessage);

          return handler.next(modifiedError);
        },
      ),
    );
    return _dio;
  }
}