import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../repositories/journal_repository.dart';
import '../../services/database_helper.dart';
import '../../models/journal_model.dart';
import 'draft_event.dart';
import 'draft_state.dart';

class DraftBloc extends Bloc<DraftEvent, DraftState> {
  final JournalRepository repository;

  DraftBloc({required this.repository}) : super(DraftLoading()) {
    on<DraftsRequested>(_onDraftsRequested);
    on<PublishPressed>(_onPublishPressed);
  }

  Future<void> _onDraftsRequested(DraftsRequested event, Emitter<DraftState> emit) async {
    emit(DraftLoading());
    try {
      List<JournalModel> combined = [];

      // 1. Ambil Draf Lokal (SQLite)
      final localDraftsData = await DatabaseHelper.instance.getDrafts();
      final localDrafts = localDraftsData.map((d) => JournalModel.fromJson(d)).toList();
      combined.addAll(localDrafts);

      // 2. Ambil Draf Server (API)
      try {
        final res = await repository.getDrafts();

        if (res.statusCode == 200 && res.data['success']) {
          List<dynamic> serverDraftsData = res.data['data'];
          final serverDrafts = serverDraftsData.map((d) => JournalModel.fromJson(d as Map<String, dynamic>)).toList();
          combined.addAll(serverDrafts);
        }
      } catch (e) {
        // Ignore or log error
      }

      // 3. Urutkan berdasarkan tanggal terbaru
      combined.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

      emit(DraftsLoaded(combined));
    } catch (e) {
      emit(DraftError("Gagal memuat draf: ${e.toString()}"));
    }
  }

  Future<void> _onPublishPressed(PublishPressed event, Emitter<DraftState> emit) async {
    // Simpan state terakhir untuk dikembalikan jika gagal publish
    final currentState = state;
    
    try {
      final res = await repository.publishJournal(event.journalId);

      if (res.statusCode == 200) {
        emit(DraftPublishSuccess("Jurnal berhasil tayang!"));
        // Muat ulang daftar setelah sukses
        add(DraftsRequested());
      } else {
        emit(DraftPublishFailed("Gagal publish jurnal."));
        if (currentState is DraftsLoaded) emit(currentState); // kembalikan ke list
      }
    } on DioException catch (e) {
      String errorMessage = "Terjadi kesalahan koneksi.";
      if (e.response != null && e.response?.data != null) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }
      emit(DraftPublishFailed(errorMessage));
      if (currentState is DraftsLoaded) emit(currentState);
    } catch (e) {
      emit(DraftPublishFailed(e.toString()));
      if (currentState is DraftsLoaded) emit(currentState);
    }
  }
}
