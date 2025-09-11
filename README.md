# Retaliation

Space-invaders style prototype in Flutter. You control the aliens; the ship is AI.

## Run

- `flutter run` (use `-d ios` or `-d android` to select a device)

## Levels

- Levels are JSON files in `assets/levels/`. The app currently loads `assets/levels/level1.json`.
- Documentation: see `docs/LEVELS.md` (schema, units, and examples).

## Analyze & Hooks

- Pre-commit runs `flutter analyze`. To run manually: `flutter analyze`.
