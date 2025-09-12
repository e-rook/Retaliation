import 'package:flutter/widgets.dart';
import '../game/game_controller.dart';

class GameControllerProvider extends InheritedNotifier<GameController> {
  const GameControllerProvider({super.key, required GameController controller, required super.child})
      : super(notifier: controller);

  static GameController of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<GameControllerProvider>();
    assert(provider != null, 'No GameControllerProvider found in context');
    return provider!.notifier!;
  }
}
