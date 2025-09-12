import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../util/log.dart';

/// Simple asset sprite cache for ui.Image.
///
/// Usage:
/// - Call SpriteStore.instance.ensure(path) to start loading.
/// - Call SpriteStore.instance.imageFor(path) to get the loaded image (or null if not yet loaded).
/// - Listen to SpriteStore.instance for changes to trigger repaint when images arrive.
class SpriteStore extends ChangeNotifier {
  SpriteStore._();
  static final SpriteStore instance = SpriteStore._();

  final Map<String, ui.Image> _images = {};
  final Map<String, Future<void>> _inflight = {};
  final Set<String> _failed = <String>{};

  ui.Image? imageFor(String path) => _images[path];
  bool hasFailed(String path) => _failed.contains(path);

  Future<void> ensure(String path) async {
    if (_images.containsKey(path) || _inflight.containsKey(path)) return _inflight[path];
    // clear failure on retry
    _failed.remove(path);
    final fut = _load(path);
    _inflight[path] = fut;
    await fut;
    _inflight.remove(path);
  }

  Future<void> _load(String path) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _images[path] = frame.image;
      logv('Sprites', 'Loaded sprite: $path');
      notifyListeners();
    } catch (e) {
      logv('Sprites', 'Failed to load sprite: $path: $e');
      _failed.add(path);
      notifyListeners();
    }
  }
}
