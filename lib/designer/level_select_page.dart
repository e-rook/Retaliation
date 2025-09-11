import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LevelSelectPage extends StatefulWidget {
  const LevelSelectPage({super.key});

  @override
  State<LevelSelectPage> createState() => _LevelSelectPageState();
}

class _LevelSelectPageState extends State<LevelSelectPage> {
  late Future<List<String>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _levelsFuture = _loadLevels();
  }

  Future<List<String>> _loadLevels() async {
    final manifestStr = await rootBundle.loadString('AssetManifest.json');
    final manifest = json.decode(manifestStr) as Map<String, dynamic>;
    final levels = manifest.keys
        .where((k) => k.startsWith('assets/levels/') && k.toLowerCase().endsWith('.json'))
        .toList()
      ..sort();
    return levels;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Level')),
      body: FutureBuilder<List<String>>(
        future: _levelsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No level files found in assets/levels/.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final path = items[index];
              return ListTile(
                title: Text(path.split('/').last),
                subtitle: Text(path),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => Navigator.pop(context, path),
              );
            },
          );
        },
      ),
    );
  }
}
