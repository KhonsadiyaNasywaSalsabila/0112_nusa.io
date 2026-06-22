import 'package:equatable/equatable.dart';

import '../../models/location_model.dart';
import '../../models/journal_model.dart';

abstract class PlaceHubState extends Equatable {
  const PlaceHubState();
  
  @override
  List<Object> get props => [];
}

class PlaceHubLoading extends PlaceHubState {}

class PlaceHubLoaded extends PlaceHubState {
  final LocationModel location;
  final List<JournalModel> rootJournals;
  final Map<String, List<JournalModel>> repliesMap;
  final String currentTheme;

  const PlaceHubLoaded(this.location, this.rootJournals, this.repliesMap, this.currentTheme);

  @override
  List<Object> get props => [location, rootJournals, repliesMap, currentTheme];
}

class PlaceHubError extends PlaceHubState {
  final String error;
  const PlaceHubError(this.error);

  @override
  List<Object> get props => [error];
}
