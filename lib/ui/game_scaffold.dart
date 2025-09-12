import 'package:flutter/material.dart';
import 'game_hud.dart';
import 'game_overlays.dart';

class GameScaffold extends StatelessWidget {
  final Widget canvas;
  final GameOverlayState overlays;
  final VoidCallback onOpenMenu;
  final GestureTapDownCallback onTapDown;
  final ValueChanged<Size> onLayout;
  final bool showTimer;
  final String timerText;
  final VoidCallback? onOverlaySelectLevel;
  final VoidCallback? onOverlayMenu;
  final VoidCallback? onOverlayRetry;
  final VoidCallback? onOverlayNext;

  const GameScaffold({
    super.key,
    required this.canvas,
    required this.overlays,
    required this.onOpenMenu,
    required this.onTapDown,
    required this.onLayout,
    required this.showTimer,
    required this.timerText,
    this.onOverlaySelectLevel,
    this.onOverlayMenu,
    this.onOverlayRetry,
    this.onOverlayNext,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            onLayout(Size(constraints.maxWidth, constraints.maxHeight));
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: onTapDown, child: canvas),
                GameOverlays(state: overlays, onSelectLevel: onOverlaySelectLevel, onMenu: onOverlayMenu, onRetry: onOverlayRetry, onNext: onOverlayNext),
                GameHud(showTimer: showTimer, timerText: timerText, onOpenMenu: onOpenMenu),
              ],
            );
          },
        ),
      ),
    );
  }
}
