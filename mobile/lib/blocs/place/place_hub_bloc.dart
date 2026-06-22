import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_client.dart';
import '../../models/location_model.dart';
import '../../models/journal_model.dart';
import 'place_hub_event.dart';
import 'place_hub_state.dart';

class PlaceHubBloc extends Bloc<PlaceHubEvent, PlaceHubState> {
  // Smart Caching: Menyimpan data berdasarkan tema
  final Map<String, Map<String, dynamic>> _cache = {};

  PlaceHubBloc() : super(PlaceHubLoading()) {
    on<HubOpened>(_onHubOpened);
  }

  Future<void> _onHubOpened(HubOpened event, Emitter<PlaceHubState> emit) async {
    // 1. Cek Cache Lokal
    if (_cache.containsKey(event.theme)) {
      final cachedData = _cache[event.theme]!;
      emit(PlaceHubLoaded(
        cachedData['location'] as LocationModel, 
        cachedData['roots'] as List<JournalModel>, 
        cachedData['replies'] as Map<String, List<JournalModel>>, 
        event.theme
      ));
      return; // Return segera agar "Seketika" tanpa jeda
    }

    // 2. Fetch ke Backend jika belum di-cache
    emit(PlaceHubLoading());
    try {
      final res = await ApiClient.instance.get(
        '/locations/${event.locationId}/journals?theme=${event.theme}',
      );

      if (res.statusCode == 200 && res.data['success']) {
        final location = LocationModel.fromJson(res.data['data']['location']);
        final journalsData = res.data['data']['journals'] as List;

        List<JournalModel> roots = [];
        Map<String, List<JournalModel>> replies = {};

        for (var jData in journalsData) {
          final j = JournalModel.fromJson(jData as Map<String, dynamic>);
          if (j.rootJournalId == null) {
            roots.add(j);
            replies[j.id] = [];
          } else {
            if (replies.containsKey(j.rootJournalId)) {
              replies[j.rootJournalId]!.add(j);
            } else {
              replies[j.rootJournalId!] = [j];
            }
          }
        }

        // 3. Simpan ke Cache
        _cache[event.theme] = {
          'location': location,
          'roots': roots,
          'replies': replies,
        };

        emit(PlaceHubLoaded(location, roots, replies, event.theme));
      } else {
        emit(const PlaceHubError("Gagal mengambil data"));
      }
    } catch (e) {
      emit(PlaceHubError(e.toString()));
    }
  }
}
