import 'dart:convert';

void main() {
  String jsonStr = '''
  {
    "media": {
      "id": "91c2dbfc-b61d-439b-bbc1-291cdf4681fd",
      "mediaUrl": "/uploads/1781779200040.jpg"
    }
  }
  ''';
  
  Map<String, dynamic> json = jsonDecode(jsonStr);
  
  List<String> media = [];
  try {
    if (json['media'] != null) {
      media = (json['media'] as List).map((m) => m['mediaUrl'].toString()).toList();
    }
    print("Success: $media");
  } catch (e) {
    print("Crash: $e");
  }
}
