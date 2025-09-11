**Level Definitions**

- Location: place JSON files in `assets/levels/` (already included in `pubspec.yaml`).
- Loader: `LevelConfig.loadFromAsset('assets/levels/<file>.json')` reads a level at app start.
- Comments: For convenience, the loader strips `// line` and `/* block */` comments before parsing.

**Coordinates & Units**

- `x`, `y`: normalized center coordinates in the range 0..1 relative to the game surface size.
- `w`, `h`: normalized width and height in the range 0..1 relative to the game surface size.
- Example: `x: 0.5, y: 0.9, w: 0.16, h: 0.035` positions a ship centered near the bottom, 16% of the screen width and 3.5% of the screen height tall.
- All velocities (e.g., bullet speed, ship move speed) are in logical pixels per second.
- Time values (e.g., reload, timers) are in seconds.

**Color Format**

- Accepts "#RRGGBB" or "#AARRGGBB" (hex); alpha defaults to `FF` if omitted.

**Schema Overview**

- LevelConfig (top-level)
- `id`: string identifier
- `title`: short name
- `description`: text shown before the level (UI hook ready, not yet rendered in-game)
- `winMessage`, `loseMessage`: texts displayed when the level ends
- `timeLimitSeconds`: number (optional). If present, a countdown appears top-left; `mm:ss` when >= 60s, otherwise seconds.
- `winConditions`: array of strings. Allowed: `ship_destroyed`, `aliens_destroyed`, `survive_time`, `timer_elapsed`.
- `loseConditions`: array of strings. Same allowed values.
- `aliens`: array of AlienSpec
- `obstacles`: array of ObstacleSpec
- `ship`: ShipSpec
 - `dance`: DanceSpec (optional)

- AlienSpec
- `x`, `y`, `w`, `h`: normalized (see above)
- `health`: integer starting health
- `asset`: optional string (future sprite path)
- `color`: optional hex color (see above)
- `speed`: number (reserved for future movement)
- `shooter`: ShooterSpec

- ObstacleSpec
- `x`, `y`, `w`, `h`: normalized (see above)
- `health`: integer
- `asset`: optional string
- `color`: optional hex color

- ShipSpec
- `x`, `y`, `w`, `h`: normalized (see above)
- `health`: integer
- `asset`: optional string
- `color`: optional hex color
- `shooter`: ShooterSpec
- `ai`: ShipAISpec

- DanceSpec
- `hSpeed`: horizontal dance speed (pixels per second). When > 0, all aliens march horizontally in lockstep.
- `vStep`: vertical step in pixels applied when the formation hits a screen edge.

- ShooterSpec
- `power`: integer damage per shot
- `reloadSeconds`: seconds between shots
- `bulletSpeed`: pixels per second (projectile speed; positive values go downward for aliens, upward for the ship in current scene)

- ShipAISpec
- `moveChancePerSecond`: probability per second to pick a new horizontal target
- `avoidChance`: probability per second to attempt a dodge when a dangerous projectile is near
- `moveSpeed`: ship horizontal speed in pixels per second

**Behavior Notes**

- You (the player) control the aliens; tap an alien to fire.
- The ship is AI-controlled: moves horizontally, fires automatically with jitter around its reload, and may dodge.
- Collisions: projectiles subtract `power` from target `health`. Objects vanish when `health <= 0`.
- Timed levels: a countdown badge appears in the top-left when `timeLimitSeconds` is set.
 - Dance behavior: the alien formation moves horizontally; when any alien would cross the screen edge, the whole formation steps down by `vStep` and reverses direction on the next frame.

**Example**

```
{
  "id": "level1",
  "title": "Opening Salvo",
  "description": "You command the aliens. Destroy the ship before time runs out.",
  "winMessage": "Ship destroyed.",
  "loseMessage": "Time's up!",
  "timeLimitSeconds": 30,
  "winConditions": ["ship_destroyed"],
  "loseConditions": ["timer_elapsed"],
  "aliens": [
    {"x": 0.18, "y": 0.18, "w": 0.09, "h": 0.05, "health": 1, "color": "#38D66B", "speed": 0,
     "shooter": {"power": 1, "reloadSeconds": 0.8, "bulletSpeed": 280}}
  ],
  "obstacles": [
    {"x": 0.50, "y": 0.72, "w": 0.18, "h": 0.04, "health": 5, "color": "#9AA0A6"}
  ],
  "ship": {
    "x": 0.5, "y": 0.92, "w": 0.16, "h": 0.035, "health": 3, "color": "#5AA9E6",
    "shooter": {"power": 1, "reloadSeconds": 0.6, "bulletSpeed": 360},
    "ai": {"moveChancePerSecond": 0.6, "avoidChance": 0.5, "moveSpeed": 220}
  }
}
```

**Adding a New Level**

- Create `assets/levels/<your-level>.json` following the schema.
- No changes to `pubspec.yaml` needed (the folder is already listed).
- Update the app to load your file if needed (default is `assets/levels/level1.json`).
