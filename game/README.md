# Nileside City - Native Godot Vertical Slice v0.1

This is the clean native rebuild of Nileside City. It replaces the single-canvas HTML experiment with a Godot 4 project designed for Android portrait play.

## What is implemented

- Continuous world terrain - no floating platforms
- Camera follow, world limits and automatic off-screen rendering culling
- Drag from anywhere to steer; no visible joystick
- Character movement with procedural walk/bob animation
- Multi-node area harvesting with resource-category rotation
- Sickles increase in number, harvesting reach, speed and power
- Direct-to-warehouse harvesting - no bag capacity or unloading step
- Separate raw inputs, local food, construction materials and trade goods
- Local food consumption, protected food reserve and population growth
- Six factories with 10 production levels and large late-game scaling
- Independent factory output buffers
- Human haulers moving finished goods to the central warehouse
- Real functional conveyor routes with moving product packets
- Three independent trade-demand lanes
- Protected trade stock so the market cannot instantly empty all inventory
- Central treasury with fast proximity collection
- Palace/city progression through seven stages
- Fixed CanvasLayer UI that does not scale with or overlap the game world
- Native JSON save, autosave, new-city reset and up to 8 hours offline progress
- Hidden test boost: tap the city badge seven times within four seconds

## Controls

- Touch and drag anywhere outside UI controls to move.
- Release to stop.
- Walk inside the sickle ring to harvest several nearby resource nodes simultaneously.
- Tap a building to open its upgrade panel.
- Walk near the market to collect accumulated treasury coins quickly.

## Project structure

- `project.godot` - Godot project configuration
- `scenes/main.tscn` - main scene
- `scripts/` - gameplay, economy, saving, workers, factories and conveyors
- `assets/` - current Egyptian production art
- `export_presets.cfg` - Android arm64 debug export
- `.github/workflows/build-android.yml` - automated APK build

## Important status

This is the first native vertical slice. The project architecture and performance model are the real production direction, but the current character uses procedural motion on a high-resolution static asset rather than a final frame-by-frame walk cycle. A proper 4-direction animation sheet is the next art milestone.


## v0.1 startup repair

- Added explicit script preloads so clean Android/headless imports resolve every custom gameplay class.
- Removed fragile cross-script custom type annotations.
- Disabled warnings-as-errors for debug builds.
- Enabled Android ETC2/ASTC texture importing.
- Corrected the non-Gradle Android preset and text script export mode.
- Added a static boot overlay. If startup code fails, the app now shows a named boot screen instead of an unexplained grey viewport.
