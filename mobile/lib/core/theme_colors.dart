import 'package:flutter/material.dart';

class ThemeColors {
  static const Map<String, Color> tagColors = {
    'VINTAGE': Color(0xFF8D6E63),
    'ALAM': Color(0xFF4CAF50),
    'KULINER': Color(0xFFFF9800),
    'SOSIAL': Color(0xFF2196F3),
    'PERSONAL': Color(0xFF9C27B0),
    'MINDFUL': Color(0xFF00BCD4),
  };

  static Color getColorForTag(String tag) {
    return tagColors[tag] ?? Colors.grey;
  }
}