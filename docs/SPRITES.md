Sprites & Assets

Source
- Simple Space by Kenney (https://kenney.nl) — License CC0 (public domain).

Where to put files
- Place PNGs under `assets/sprites/simple_space/`.
- Current expected paths:
  - `assets/sprites/simple_space/aliens/alien1.png`
  - `assets/sprites/simple_space/aliens/alien2.png`
  - `assets/sprites/simple_space/aliens/alien3.png`
  - `assets/sprites/simple_space/aliens/alien4.png`
  - `assets/sprites/simple_space/aliens/alien5.png`
  - `assets/sprites/simple_space/ship/player.png`
- Optional shield tile: `assets/sprites/simple_space/tiles/shield_tile.png`

pubspec.yaml
- Explicitly list the sprites under `flutter/assets:` so Flutter bundles them.
- After changes, run a full rebuild:
  - `flutter clean`
  - `flutter pub get`
  - `flutter run`

Usage in levels
- Set the `asset` field to the full asset path for aliens/ship/obstacles.
- The painter tints sprites to the object `color` (aliens & ship), and flashes white on hit.
- If a sprite is still loading: it is skipped for that frame; if missing/failed: a colored rectangle fallback is drawn.

Designer
- Presets map Alien 1..5 to `alien1.png`..`alien5.png` and colors.
- The designer canvas renders sprites with tint, or rectangles if missing.

