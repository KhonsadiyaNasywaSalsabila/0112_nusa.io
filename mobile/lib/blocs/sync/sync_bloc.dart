import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../services/database_helper.dart';
import '../../services/api_client.dart';
import '../../repositories/journal_repository.dart';
import '../../models/location_model.dart';
import 'sync_event.dart';
import 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final JournalRepository repository;

  SyncBloc({required this.repository}) : super(SyncIdle()) {
    on<ConnectivityRestored>(_onSyncTriggered);
    on<ManualSyncTriggered>(_onSyncTriggered);
  }

  Future<void> _onSyncTriggered(SyncEvent event, Emitter<SyncState> emit) async {
    // Prevent overlapping syncs
    if (state is SyncInProgress) return;

    try {
      final dbHelper = DatabaseHelper.instance;
      
      // 1. Ambil semua draft lokal
      final drafts = await dbHelper.getDrafts();
      
      if (drafts.isEmpty) {
        // Jika tidak ada draft, kita bisa langsung lompat ke refresh locations cache
        await _refreshMapCache(dbHelper);
        emit(SyncCompleted());
        return;
      }

      emit(SyncInProgress(drafts.length));

      // 2. Persiapkan data untuk batch sync
      List<Map<String, dynamic>> syncPayload = [];

      for (var draft in drafts) {
        List<String> mediaUrls = [];

        // 3. Upload media lokal (jika ada) ke endpoint /media/upload
        if (draft['imagePaths'] != null && draft['imagePaths'].toString().isNotEmpty) {
          List<String> localPaths = draft['imagePaths'].split(',');
          FormData formData = FormData();
          
          for (var path in localPaths) {
            File file = File(path);
            if (file.existsSync()) {
              formData.files.add(MapEntry(
                'photos',
                await MultipartFile.fromFile(path, filename: path.split('/').last)
              ));
            }
          }

          if (formData.files.isNotEmpty) {
            final uploadRes = await ApiClient.instance.post(
              '/media/upload',
              data: formData,
            );
            
            if (uploadRes.statusCode == 201) {
              // Cast from dynamic list to string list safely
              mediaUrls = List<String>.from(uploadRes.data['data']);
            }
          }
        }

        // Susun payload draft + mediaUrls
        syncPayload.add({
          'id': draft['id'], // Local ID (Opsional, untuk mapping)
          'locationId': draft['locationId'],
          'content': draft['content'],
          'themeTag': draft['themeTag'],
          'latitudeCaptured': draft['latitudeCaptured'],
          'longitudeCaptured': draft['longitudeCaptured'],
          'isMocked': draft['isMocked'] == 1,
          'mediaUrls': mediaUrls
        });
      }

      // 4. Kirim batch sync ke backend
      final syncRes = await repository.syncJournals(syncPayload);

      if (syncRes.statusCode == 201) {
        // 5. Jika sukses, hapus semua draf lokal
        final db = await dbHelper.database;
        await db.delete('draft_journals');
        
        // 6. Segarkan Location Cache
        await _refreshMapCache(dbHelper);
        
        emit(SyncCompleted());
      } else {
        emit(SyncFailed("Gagal sinkronisasi data ke peladen."));
      }

    } catch (e) {
      emit(SyncFailed(e.toString()));
    }
  }

  Future<void> _refreshMapCache(DatabaseHelper dbHelper) async {
    try {
      final mapRes = await ApiClient.instance.get('/map');
      if (mapRes.data['success']) {
        final List<dynamic> data = mapRes.data['data'];
        final locations = data.map((json) => LocationModel.fromJson(json as Map<String, dynamic>)).toList();
        await dbHelper.cacheLocations(locations);
      }
    } catch (e) {
      // Abaikan jika error refresh cache, bukan fatal error untuk sinkronisasi
    }
  }
}
