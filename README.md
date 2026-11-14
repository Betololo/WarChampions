# War Champions

Spiritual tribute remake of **Battlefield Heroes (2009)** built in **Godot 4.7.2** (statically typed GDScript) with a **12 vs 12 (24-player)** **Dedicated Server Authoritative** ENet architecture.

## Highlights
- **Real ENet Online Multiplayer (Zero Forced Bots):** Host (`Criar Sala Online`) or join via IP:Port (`Entrar na Partida Online`) with 2-channel ENet (`Reliable` events + `Unreliable Ordered` 60Hz inputs / 30Hz snapshots using full 32-bit ENet `peer_id`s), 15-byte bitpacked `InputCmd`, 128-tick Client-Side Prediction & Server Reconciliation, 100ms Entity Interpolation, and Server-Side Hitbox Rewind (`LagCompensator`).
- **3 Classes & Exclusive Loadouts + 15 Skills (Levels 1–30):**
  - **Soldier (110 HP):** SMG, Shotgun, Pistol, TNT
  - **Gunner (150 HP):** Heavy MG, Shotgun, Bazooka
  - **Commando (80 HP):** Sniper Rifle (FPS Scope), Knife, Pistol, TNT
  - Plus 5 upgradeable skills per class (ranks 1–5 via Hero Points), infinite reserve ammo, infinite reusable parachute with prompt (`[ESPAÇO] Abrir Paraquedas`) & fall damage, and 3 Widgets (Bandages, Wrench, Antidote/Fireproof Underwear).
- **Articulated Heroes, Animations & Cartoon HUD:** Procedural Half-Lambert + Rim Lighting characters with distinct class silhouettes, animated limbs/weapons/parachute/defeat, procedural hand-painted textures & 2D HUD sprites (`CartoonAssets`), over-the-shoulder TPS camera, top-left XP ring + portrait, top-center Crown & Skull flag multipliers + damage arc, and bottom-center 1–0 hotbar.
- **Land, Air & Water Cooperative Vehicles:** Recon Jeeps, Heavy Tanks (360° turret, parabolic shell, 2.0x rear armor damage, rear repair seat), Fighter Planes with **Wing-Riding**, Patrol/Landing Boats with buoyancy physics, and fixed AA Flak guns.
- **Large Coastal Town Map (`Seaside Frontline`):** Cobblestone streets, sidewalks, 16+ village buildings, 2 airbase hangars, 60+ cartoon trees, crate cover, runways, 4 diamond Capture Points, destructible props, and Conquest 12v12 rules (50 tickets + 1x/2x/3x multipliers). Optional `Treino Offline com Bots (12v12)` mode included for solo testing.

## Running on Windows
- **Play directly:** Double-click `Jogar_War_Champions.bat`
- **Edit in Godot:** Double-click `Abrir_no_Godot_Editor.bat`
- **Test 2-Player Local Multiplayer (1 click):** Double-click `Testar_Multiplayer_2_Clientes.bat` (opens Host Royal + Client National side-by-side on `127.0.0.1:7777`)
- **Dedicated headless server:** `godot_console.exe --headless -- --server --port=7777`
- **Automated headless test suite:** `godot_console.exe --headless res://tests/test_runner.tscn`
