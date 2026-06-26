import 'package:dio/dio.dart';
import '../services/api_client.dart';

class JournalRepository {
  final Dio _dio = ApiClient.instance;

  Future<Response> getDrafts() async {
    return await _dio.get('/journals/drafts');
  }

  Future<Response> createJournal(FormData data) async {
    return await _dio.post('/journals', data: data);
  }

  Future<Response> updateJournal(String id, FormData data) async {
    return await _dio.patch('/journals/$id', data: data);
  }

  Future<Response> publishJournal(String id) async {
    return await _dio.patch('/journals/$id/publish');
  }

  Future<Response> archiveJournal(String id) async {
    return await _dio.patch('/journals/$id/archive');
  }

  Future<Response> deleteJournal(String id) async {
    return await _dio.delete('/journals/$id');
  }

  Future<Response> syncJournals(List<dynamic> draftsToSync) async {
    return await _dio.post(
      '/journals/sync',
      data: {'drafts': draftsToSync},
    );
  }

}
