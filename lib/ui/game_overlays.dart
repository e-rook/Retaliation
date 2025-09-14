import 'package:flutter/material.dart';
import 'widgets/typewriter.dart';

class GameOverlayState {
  final GameOverlayKind kind;
  final String? message;
  final String? title;
  final String? description;

  const GameOverlayState._(this.kind, {this.message, this.title, this.description});
  const GameOverlayState.none() : this._(GameOverlayKind.none);
  const GameOverlayState.loading() : this._(GameOverlayKind.loading);
  const GameOverlayState.error(String msg) : this._(GameOverlayKind.error, message: msg);
  const GameOverlayState.win(String msg) : this._(GameOverlayKind.win, message: msg);
  const GameOverlayState.lose(String msg) : this._(GameOverlayKind.lose, message: msg);
  const GameOverlayState.intro({required String title, required String description})
      : this._(GameOverlayKind.intro, title: title, description: description);
}

enum GameOverlayKind { none, loading, error, win, lose, intro }

class GameOverlays extends StatelessWidget {
  final GameOverlayState state;
  final VoidCallback? onSelectLevel;
  final VoidCallback? onMenu;
  final VoidCallback? onRetry;
  final VoidCallback? onNext;
  final VoidCallback? onIntroDone;

  const GameOverlays({super.key, required this.state, this.onSelectLevel, this.onMenu, this.onRetry, this.onNext, this.onIntroDone});

  @override
  Widget build(BuildContext context) {
    Widget? overlay;
    switch (state.kind) {
      case GameOverlayKind.none:
        overlay = null;
        break;
      case GameOverlayKind.loading:
        overlay = const _MessageCard(text: 'Loading level...');
        break;
      case GameOverlayKind.error:
        overlay = _MessageCard(text: state.message ?? 'Error');
        break;
      case GameOverlayKind.intro:
        overlay = _IntroCard(
          title: state.title ?? '',
          description: state.description ?? '',
          onDone: onIntroDone,
        );
        break;
      case GameOverlayKind.win:
        overlay = _WinLoseCard(
          message: state.message ?? 'You won!',
          primaryLabel: 'Next Level',
          onPrimary: onNext,
          secondaryLabel: 'Select Level',
          onSecondary: onSelectLevel,
        );
        break;
      case GameOverlayKind.lose:
        overlay = _WinLoseCard(
          message: state.message ?? 'Try again',
          primaryLabel: 'Retry',
          onPrimary: onRetry,
          secondaryLabel: 'Menu',
          onSecondary: onMenu,
        );
        break;
    }

    if (overlay == null) return const SizedBox.shrink();
    return Center(child: overlay);
  }
}

class _MessageCard extends StatelessWidget {
  final String text;
  const _MessageCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }
}

class _WinLoseCard extends StatelessWidget {
  final String message;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _WinLoseCard({
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: onPrimary,
                child: Text(primaryLabel),
              ),
              if (secondaryLabel != null) const SizedBox(width: 8),
              if (secondaryLabel != null)
                OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onDone;

  const _IntroCard({required this.title, required this.description, this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            TypewriterText(
              text: description,
              onDone: onDone,
              style: const TextStyle(fontFamily: 'Courier', color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 24,
            ),
          ],
        ),
      ),
    );
  }
}
