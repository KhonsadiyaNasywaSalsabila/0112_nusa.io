import 'package:dio/dio.dart';
import '../services/api_client.dart';

class BookmarkRepository {
  final Dio _dio = ApiClient.instance;

  // --- Lokasi (Rencana Jelajah) ---
  Future<Response> bookmarkLocation(String locationId) async {
    return await _dio.post('/bookmarks/locations', data: {'locationId': locationId});
  }

  Future<Response> getBookmarkedLocations({int page = 1, int limit = 10, String? search}) async {
    final Map<String, dynamic> params = {'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    return await _dio.get('/bookmarks/locations', queryParameters: params);
  }

  Future<Response> removeBookmarkedLocation(String id) async {
    return await _dio.delete('/bookmarks/locations/$id');
  }

  Future<Response> removeBookmarkedLocationByLocationId(String locationId) async {
    return await _dio.delete('/bookmarks/locations/by-location/$locationId');
  }

  // --- Jurnal (Koleksi / Inspirasi) ---
  Future<Response> saveJournal(String journalId) async {
    return await _dio.post('/bookmarks/journals', data: {'journalId': journalId});
  }

  Future<Response> getSavedJournals({int page = 1, int limit = 5, String? search}) async {
    final Map<String, dynamic> params = {'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    return await _dio.get('/bookmarks/journals', queryParameters: params);
  }

  Future<Response> unsaveJournal(String id) async {
    return await _dio.delete('/bookmarks/journals/$id');
  }

  Future<Response> unsaveJournalByJournalId(String journalId) async {
    return await _dio.delete('/bookmarks/journals/by-journal/$journalId');
  }
}
