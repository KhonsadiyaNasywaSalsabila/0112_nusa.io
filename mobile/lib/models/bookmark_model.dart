import 'location_model.dart';
import 'journal_model.dart';

class BookmarkModel {
  final String id;
  final String status;
  final DateTime? createdAt;
  final LocationModel? location;
  final JournalModel? journal;

  BookmarkModel({
    required this.id,
    required this.status,
    this.createdAt,
    this.location,
    this.journal,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'] ?? '',
      status: json['status'] ?? 'PLANNED',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      location: json['location'] != null ? LocationModel.fromJson(json['location']) : null,
      journal: json['journal'] != null ? JournalModel.fromJson(json['journal']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      if (location != null) 'location': location!.toJson(),
      if (journal != null) 'journal': journal!.toJson(),
    };
  }
}
