import 'user_model.dart';

class JournalModel {
  final String id;
  final String content;
  final String themeTag;
  final String status;
  final double latitudeCaptured;
  final double longitudeCaptured;
  final String? rootJournalId;
  final DateTime? createdAt;
  
  // Relasi
  final UserModel? user;
  final List<String> mediaUrls;

  // Khusus Local Draft
  final bool isLocal;
  final List<String> localMediaPaths;

  JournalModel({
    required this.id,
    required this.content,
    required this.themeTag,
    required this.status,
    required this.latitudeCaptured,
    required this.longitudeCaptured,
    this.rootJournalId,
    this.createdAt,
    this.user,
    this.mediaUrls = const [],
    this.isLocal = false,
    this.localMediaPaths = const [],
  });

  factory JournalModel.fromJson(Map<String, dynamic> json) {
    List<String> media = [];
    if (json['media'] != null) {
      if (json['media'] is List) {
        media = (json['media'] as List).map((m) => m['mediaUrl'].toString()).toList();
      } else if (json['media'] is Map) {
        media = [json['media']['mediaUrl'].toString()];
      }
    }

    return JournalModel(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      themeTag: json['themeTag'] ?? 'NATURE',
      status: json['status'] ?? 'DRAFT',
      latitudeCaptured: double.tryParse(json['latitudeCaptured']?.toString() ?? '0') ?? 0.0,
      longitudeCaptured: double.tryParse(json['longitudeCaptured']?.toString() ?? '0') ?? 0.0,
      rootJournalId: json['rootJournalId'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      mediaUrls: media,
      isLocal: json['isLocal'] == 1 || json['isLocal'] == true, // Handle SQLite 1/0
      localMediaPaths: json['localMediaPaths'] != null 
          ? (json['localMediaPaths'] as String).split(',') 
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'themeTag': themeTag,
      'status': status,
      'latitudeCaptured': latitudeCaptured,
      'longitudeCaptured': longitudeCaptured,
      'rootJournalId': rootJournalId,
      'isLocal': isLocal ? 1 : 0,
      'localMediaPaths': localMediaPaths.join(','),
      // 'createdAt' and 'user' usually aren't sent back to the server in this format during creation
    };
  }
}
