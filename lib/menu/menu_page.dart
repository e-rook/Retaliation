import 'package:flutter/material.dart';
import '../designer/level_select_page.dart';
import '../main.dart' show GamePage; // reuse GamePage
import 'package:shared_preferences/shared_preferences.dart';
import '../game/level_list.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retaliation')),
      body: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuButton(
                label: 'Continue',
                icon: Icons.play_circle_fill,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final order = await LevelList.loadFromAsset('assets/levels/levels.json');
                  final unlocked = (prefs.getInt('unlocked_count') ?? 1).clamp(1, order.levels.length);
                  final path = order.levels.isNotEmpty ? order.levels[unlocked - 1] : null;
                  if (path != null) {
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GamePage(initialLevelPath: path),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              _MenuButton(
                label: 'Play',
                icon: Icons.play_arrow,
                onTap: () async {
                  final selected = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => const LevelSelectPage()),
                  );
                  if (selected != null) {
                    // Push game with selected level path
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GamePage(initialLevelPath: selected),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              _MenuButton(
                label: 'Settings',
                icon: Icons.settings,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _SettingsPage()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _MenuButton(
                label: 'Help',
                icon: Icons.help_outline,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _HelpPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MenuButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(label),
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Text('Settings coming soon.'),
      ),
    );
  }
}

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            'How to play:\n\n'
            '- You control the aliens. Tap an alien to fire.\n'
            '- The ship at the bottom is AI and shoots back.\n'
            '- Projectiles reduce health; flashing indicates a hit.\n'
            '- Destroy the ship before time runs out.\n\n'
            'Designer:\n'
            '- Long-press the timer to open the level designer.\n'
            '- Toolbar is scrollable. Tap to place; tap to select; drag to move; double-tap to delete.\n'
            '- Share JSON via the share button.\n\n'
            'Levels:\n'
            '- Use the Levels button to pick an ordered level.\n'
            '- Winning unlocks the next level.',
          ),
        ),
      ),
    );
  }
}
