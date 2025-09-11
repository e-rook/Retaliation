import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/level_list.dart';
import '../game/level.dart';

class LevelSelectPage extends StatefulWidget {
  const LevelSelectPage({super.key});

  @override
  State<LevelSelectPage> createState() => _LevelSelectPageState();
}

class _LevelSelectPageState extends State<LevelSelectPage> {
  late Future<List<_Entry>> _levelsFuture;
  int _unlocked = 1;

  @override
  void initState() {
    super.initState();
    _levelsFuture = _loadLevels();
  }

  Future<List<_Entry>> _loadLevels() async {
    // Load ordered list
    final order = await LevelList.loadFromAsset('assets/levels/levels.json');
    // Prefs for unlocks
    final prefs = await SharedPreferences.getInstance();
    _unlocked = prefs.getInt('unlocked_count') ?? 1;
    if (_unlocked < 1) _unlocked = 1;
    final entries = <_Entry>[];
    for (int i = 0; i < order.levels.length; i++) {
      final path = order.levels[i];
      try {
        final lvl = await LevelConfig.loadFromAsset(path);
        entries.add(_Entry(path: path, index: i, name: lvl.title));
      } catch (_) {
        entries.add(_Entry(path: path, index: i, name: path.split('/').last));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Level')),
      body: FutureBuilder<List<_Entry>>(
        future: _levelsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <_Entry>[];
          if (items.isEmpty) {
            return const Center(child: Text('No level files found in assets/levels/.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final e = items[index];
              final locked = index >= _unlocked;
              return ListTile(
                title: Text(e.name),
                subtitle: Text(e.path),
                leading: Icon(locked ? Icons.lock : Icons.lock_open, color: locked ? Colors.redAccent : Colors.greenAccent),
                trailing: locked ? null : const Icon(Icons.play_arrow),
                enabled: !locked,
                onTap: locked ? null : () => Navigator.pop(context, e.path),
              );
            },
          );
        },
      ),
    );
  }
}

class _Entry {
  final String path;
  final int index;
  final String name;
  _Entry({required this.path, required this.index, required this.name});
}
