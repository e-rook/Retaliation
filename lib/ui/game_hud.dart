import 'package:flutter/material.dart';

class GameHud extends StatelessWidget {
  final bool showTimer;
  final String timerText;
  final VoidCallback onOpenMenu;

  const GameHud({super.key, required this.showTimer, required this.timerText, required this.onOpenMenu});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showTimer)
          Positioned(
            left: 10,
            top: 8,
            child: TimerBadge(text: timerText),
          ),
        Positioned(
          right: 8,
          top: 8,
          child: _MenuButton(onTap: onOpenMenu),
        ),
      ],
    );
  }
}

class TimerBadge extends StatelessWidget {
  final String text;
  const TimerBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Menu', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
