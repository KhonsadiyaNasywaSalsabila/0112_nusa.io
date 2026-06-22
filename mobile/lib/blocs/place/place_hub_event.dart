import 'package:equatable/equatable.dart';

abstract class PlaceHubEvent extends Equatable {
  const PlaceHubEvent();

  @override
  List<Object> get props => [];
}

class HubOpened extends PlaceHubEvent {
  final String locationId;
  final String theme;
  const HubOpened(this.locationId, {this.theme = 'Semua'});

  @override
  List<Object> get props => [locationId, theme];
}
