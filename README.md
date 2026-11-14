# War Champions

Spiritual tribute remake of **Battlefield Heroes (2009)** built from scratch in **Godot 4.7.2** (statically typed GDScript) with a **12 vs 12 (24-player)** **Dedicated Server Authoritative** ENet architecture.

## Highlights
- **Zero-Lag ENet Netcode:** 2-channel ENet (`Reliable` events + `Unreliable Ordered` 60Hz inputs / 30Hz snapshots), 15-byte bitpacked `InputCmd`, 128-tick Client-Side Prediction & Server Reconciliation, 100ms Entity Interpolation, and Server-Side Hitbox Rewind (`LagCompensator`).
- **3 Hero Classes & 15 Skills (Levels 1–30):** Soldier (110 HP), Gunner (150 HP), Commando (80 HP), 5 skills each (ranks 1–5 with Hero Points), 3 Weapon Archetypes (Balanced, Fast Short-Range, Slow Long-Range) with infinite reserve ammo, plus 3 Widgets (Bandages, Wrench, Fireproof Underwear / Antidote).
- **Land, Air & Water Cooperative Vehicles:** Recon Jeeps, Heavy Tanks (360° turret, parabolic shell, 2.0x rear armor damage, rear repair seat), Fighter Planes with **Wing-Riding**, Patrol/Landing Boats with buoyancy physics, and fixed AA Flak guns.
- **1 Large Coastal Map (`Seaside Frontline`):** ~800m × 800m island & navigable ocean with 4 diamond/zig-zag Capture Points, 3-layer urban verticality, clear runways, destructible fences/crates/red barrels, and Conquest 12v12 (50 tickets + flag multipliers), Hero of the Hill, and CTF support.
- **Cartoon Presentation:** Stylized V-torso character proportions, Half-Lambert + Rim Lighting + Stealth refraction shader, no-blood cartoon VFX, procedural Whistle Theme & SFX synthesizer, and AI bots for solo 12v12 testing.

## Running
- Open in **Godot 4.7.2+** and press **F5** (Play) to host, join, or launch a 12v12 bot match.
- Dedicated headless server: `godot --headless -- --server --port=7777`
- Automated headless test suite: `godot_console --headless --script res://tests/test_runner.gd`
