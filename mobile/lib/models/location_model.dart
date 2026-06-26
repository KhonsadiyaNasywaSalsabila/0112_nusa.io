import 'journal_model.dart';

class LocationModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double geofenceRadius;
  final String? coverPhotoUrl;
  final String? description;
  final int journalCount;
  final bool isActive;
  
  // Fitur MapExplore
  final List<String> availableThemes;
  final bool isBookmarked;
  final bool isVisited;
  final List<JournalModel> journals;

  LocationModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadius,
    this.coverPhotoUrl,
    this.description,
    this.journalCount = 0,
    this.isActive = true,
    this.availableThemes = const [],
    this.isBookmarked = false,
    this.isVisited = false,
    this.journals = const [],
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    List<JournalModel> parsedJournals = [];
    if (json['journals'] != null) {
      parsedJournals = (json['journals'] as List)
          .map((j) => JournalModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }

    List<String> parsedThemes = [];
    if (json['availableThemes'] != null) {
      parsedThemes = (json['availableThemes'] as List).map((t) => t.toString()).toList();
    }

    return LocationModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? json['lng']?.toString() ?? '0') ?? 0.0,
      geofenceRadius: double.tryParse(json['geofenceRadius']?.toString() ?? '0') ?? 0.0,
      coverPhotoUrl: json['coverPhotoUrl'],
      description: json['description'],
      journalCount: json['journalCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      availableThemes: parsedThemes,
      isBookmarked: json['isBookmarked'] ?? false,
      isVisited: json['isVisited'] ?? false,
      journals: parsedJournals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'geofenceRadius': geofenceRadius,
      'coverPhotoUrl': coverPhotoUrl,
      'description': description,
      'journalCount': journalCount,
      'isActive': isActive,
      'availableThemes': availableThemes,
      'isBookmarked': isBookmarked,
      'isVisited': isVisited,
      'journals': journals.map((j) => j.toJson()).toList(),
    };
  }
}
