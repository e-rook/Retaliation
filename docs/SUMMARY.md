Project Summary

Overview
- 2D Space-Invaders-style prototype in Flutter (Android + iOS).
- Player controls the aliens; the ship is AI-controlled.
- Sprites (Simple Space by Kenney) for aliens and ship; obstacles can be tiled and partially destructible.

Core Features
- Gameplay
  - Two rows of 6 aliens; tap an alien to shoot downward.
  - Ship at the bottom moves with simple AI (random targets + projectile avoidance) and fires upward.
  - Collisions: projectiles subtract health; objects are removed at health <= 0.
  - Hit flash effect on aliens, obstacles, ship.
  - Alien dance: formation marches horizontally, drops down, and reverses at edges (classic behavior).

- Levels & Progression
  - Level JSON files: aliens, ship, obstacles, dance, rules; see docs/LEVELS.md.
  - Ordered levels (assets/levels/levels.json) define play order.
  - Unlock progression saved in SharedPreferences (first level unlocked by default; winning unlocks the next).
  - Level picker (Levels button or Menu → Play) shows levels in order with lock state.
  - Win/Loss overlays: tap to go back to the level list.

- Designer
  - Open by long-pressing the timer during gameplay.
  - Scrollable toolbar with tools:
    - Aliens: 5 presets (sprite + color + size + shooter), place by tap.
    - Obstacle: add block or tiled shield (rows/cols), per-tile HP.
    - Ship: reposition, edit color/health/shooter.
    - Dance parameters: horizontal speed and vertical step.
  - Select + drag to move; double-tap to delete.
  - Share level as JSON via native share sheet.

- Rendering & Sprites
  - Simple Space sprites (Kenney); tint applied based on object color.
  - Painter renders sprites when available; skips rectangles until load completes; falls back to rectangles only if sprite is missing/failed.
  - SpriteStore caches ui.Image and notifies listeners on load/failure.

UI Navigation
- Menu screen
  - Continue: jump to highest unlocked level.
  - Play: open ordered Level List.
  - Settings: placeholder.
  - Help: basic instructions.

Files of Interest
- lib/main.dart — game loop, painter, input, overlays, progression, level boot.
- lib/game/objects.dart — object model (GameObject, Alien, UFO, PlayerShip, Obstacle) with Shooter mixin.
- lib/game/projectile.dart — projectile state and movement.
- lib/game/level.dart — level schema + loader (comment stripping + toJson).
- lib/game/level_list.dart — ordered level list loader.
- lib/game/level_validator.dart — validation of coordinates, sizes, health, shooters, tiles.
- lib/gfx/sprites.dart — sprite loader/cache with change notifications and failure tracking.
- lib/designer/designer_page.dart — in-app level designer.
- lib/designer/level_select_page.dart — Level picker (ordered, with locks).
- lib/menu/menu_page.dart — Main menu, Continue/Play/Settings/Help.
- assets/levels/level1.json — sample level using sprites + colors.
- assets/levels/levels.json — ordered list of levels to play.

Assets
- Add Simple Space PNGs under assets/sprites/simple_space/ and list them in pubspec.yaml assets.
- Current explicit entries include 5 alien PNGs and 1 ship PNG.

Build/Run
- flutter pub get
- flutter run (use -d ios or -d android to select device)
- Full restart required after changing pubspec or adding new assets.

Testing & Analyze
- Pre-commit hook runs flutter analyze; to run manually: flutter analyze.

Troubleshooting
- Sprites render as rectangles or not at all:
  - Ensure asset paths exist and are listed in pubspec.yaml assets.
  - Run flutter clean; flutter pub get; flutter run.
  - Watch logs for [Assets] FOUND/MISSING and [Sprites] Loaded/Failed messages.

Licensing
- Simple Space by Kenney — CC0 (public domain). No attribution required; attribution appreciated.

