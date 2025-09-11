import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LevelList {
  final List<String> levels; // asset paths in play order
  const LevelList(this.levels);

  static Future<LevelList> loadFromAsset(String path) async {
    final raw = await rootBundle.loadString(path);
    final map = json.decode(raw) as Map<String, dynamic>;
    final list = ((map['levels'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return LevelList(list);
  }
}

