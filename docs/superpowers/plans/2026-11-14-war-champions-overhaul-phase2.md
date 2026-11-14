# War Champions Overhaul — Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all Phase-2 gameplay, terrain, UI, audio, AI, animation, physics/knockback, netcode jitter/sequencing, and menu issues raised after Request #9 so **War Champions** plays smoothly offline (12v12 bots) and online (ENet multiplayer / VPS dedicated server) and merges cleanly into `main`.

**Architecture:** Build directly on the existing deterministic 60Hz tick simulation (`MainGame` + `HeroCharacter` + `NetworkManager` + `LagCompensator`), procedural BFH cartoon asset pipeline (`CartoonAssets` + `HeroMeshBuilder` + `BuildingMeshBuilder`), and Forward+ / headless dual verification (`tests/test_runner.gd`). No external asset dependencies; every fix uses clean helper APIs and automated verification assertions.

**Tech Stack:** Godot 4.7.2 (`godot_console.exe` at `$env:LOCALAPPDATA\Microsoft\WinGet\Links\godot_console.exe`), GDScript, ENet `ENetMultiplayerPeer`, Forward+ Vulkan (`AMD Radeon RX 7600`) & headless verification.

**Global Constraints:**
- Never break any existing test invariant in `tests/test_runner.gd` (or explicitly update terrain collider assertions ONLY where Task 6 upgrades flat `GrassMainland` boxes into sculpted `ConcavePolygonShape3D` heightfield terrain).
- Every opaque `StandardMaterial3D` (`albedo_color.a >= 0.99`) MUST use `BaseMaterial3D.TRANSPARENCY_DISABLED`; only glass/water/cloak shaders use `TRANSPARENCY_ALPHA`.
- Every `ArrayMesh` inside `MapSeasideFrontline` or `HeroMeshBuilder` / `VehicleMeshBuilder` with `>= 12` faces MUST maintain positive outward CW volume (`_signed_volume_outward_cw > 0.0`).
- Zero friendly fire on teammates (`team == owner_team` and `id != owner_id`); zero self-damage on explosive knockback/rocket-jumps (`id == owner_id`).
- If any `class_name` or shader changes, run `--headless --import --quit` before running `res://tests/test_runner.tscn`. Always run Forward+ visual checks without `--headless`.
- Never bind test servers on port `7777` (use `7798`–`7810`) and never kill any running user `godot.exe` window.

---

### Task 6: Stylized Sky Clouds, Sculpted Hills/Colinas, Navigable Central River + River Boats, & Farm/Rural POIs

**Files:**
- Create: `vfx_shaders/toon_sky.gdshader`
- Modify: `maps/building_mesh_builder.gd`
- Modify: `maps/map_seaside_frontline.gd`
- Modify: `core/main_game.gd` (if terrain height query is helpful for safe spawns/respawns)
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **Cartoon Sky with Layered Clouds (`vfx_shaders/toon_sky.gdshader` + `MapSeasideFrontline._build_sky_and_lighting`):**
   - Replace plain cloud-free `ProceduralSkyMaterial` with a custom `shader_type sky;` toon sky shader rendering saturated azure zenith, pale horizon gradient, crisp sun disc + soft halo, and multiple animated/drifting layered puffy cartoon BFH cumulus cloud bands (soft cel steps, sunlit creamy tops, cool periwinkle undersides).
   - Keep `env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY` and `ambient_light_energy = 0.78` so ambient lighting stays bright and clean.
2. **Continuous Sculpted Hills Terrain (`MapSeasideFrontline.get_terrain_height` & `_build_ocean_and_terrain`):**
   - Implement `static func get_terrain_height(x: float, z: float) -> float` sculpting undulating hills & valleys across the `1440m x 920m` mainland:
     - Keep smooth flat/level pads for `TownSquarePlaza` (`|x| < 75, |z - 40| < 70` at `Y = 2.15`), `MainRoadEW` corridor (`|z - 40| < 18` except bridge approach ramps!), `RoyalRunway` (`x in [-620,-350], z in [-130,-50]`), `NationalRunway` (`x in [350,620], z in [65,145]`), Spawn zones (`|x| in [410,500], |z - 12| < 48`), Windmill plateau (`(-230,-240)` base blend), Ruins cliff (`(280,-240)` base blend), Lighthouse cliff (`(-470,315)` base blend), and Harbor waterfront (`z > 420`).
     - Sculpt dramatic, drivable/walkable rolling hills (`morros e colinas`, peak heights `+6m` to `+14m` above `2.15m`) in North-Central hills (`X in [-90, 90], Z in [-380, -180]`), South-West valley ridges (`X in [-300, -90], Z in [160, 360]`), North-East rural ridge (`X in [380, 620], Z in [-360, -140]`), and South-East farm hills (`X in [260, 580], Z in [210, 380]`).
     - Carve a **continuous North-South Navigable Central River** along `river_center_x(z: float) -> float = 158.0 + sin(z * 0.007) * 26.0`: channel half-width `22.0m` (`44m` shoreline-to-shoreline), flat deep riverbed `Y = -3.6m` (`>= 2.8m` below ocean `Y = -0.35m` / physics `Y = 0.0`), sloping sandy/grassy riverbanks smoothly joining the island terrain (`Y = 2.15m+`) so the river visibly connects the North Beach/Sea (`Z <= -460`) continuously all the way through the island to the South Beach/Sea (`Z >= 460`)!
   - Build `SculptedTerrain` (`MeshInstance3D` + `StaticBody3D` Layer 1 with `ConcavePolygonShape3D`) from a clean grid (e.g. `12m` cells across `1600m x 1080m`), **closed watertight with perimeter skirts & bottom face** so `_signed_volume_outward_cw(am) > 0.0`! Paint vertex colors seamlessly blending wet sand near shore/riverbed, warm sandy beach, lush emerald meadow, and sunlit hillside moss with `CartoonAssets.get_texture("grass")` detail.
   - Keep `BeachBase` node name/metadata clean (or enclose sand skirts cleanly under terrain; update `_test_double_map_architecture_and_landmarks` to validate `SculptedTerrain` trimesh collider coverage `>= 1600m x 1080m`, hill relief `>= 8m`, and continuous North-South river bed `Y <= -2.5m`).
3. **Navigable River Bridges & Boats Inside the Central River:**
   - Because `River` crosses `MainRoadEW` around `(X ≈ 165, Z = 40)` and `SouthCoastalRoad` around `(X ≈ 159, Z = 444)`:
     - Split/shape `MainRoadEW` and sidewalks across the river gap (`X in [125, 205]`), and construct **`MainRiverBridge`** (arched stone/steel BFH bridge with deck crown `Y = 5.4m` — giving `> 5.0m` vertical clearance above `Y = 0.0` water for boats underneath — and `>= 18m` drivable width with smooth cobble approach ramps so Tanks & Jeeps drive right over!).
     - Construct **`SouthRiverBridge`** along `SouthCoastalRoad` (`Z = 444`, deck `Y = 5.2m`) so coastal traffic crosses smoothly above the river mouth.
     - Construct **2 Riverboat Docks (`RiverTownDock` near `(136, 0, -45)`, `RiverNorthDock` near `(134, 0, -280)`)** and moor **4 River `VehicleBoat` instances** in deep central river water (`Y = -0.15`, facing North/South along channel), keeping the existing 6 Ocean Harbor Pier boats intact (`10 Boats total`).
     - Shift East Boulevard houses that previously sat inside `X in [125, 205]` outward onto solid ground west/east of the riverbanks (`X = 104` / `X = 224`) so zero houses float in water!
4. **Farm (`Fazenda`) & Rural Population:**
   - Add `BuildingMeshBuilder.build_farm_complex(parent, pos, yaw, name_prefix)`: red wood barn (`RedBarn`) with white trim & pitched terracotta/shingle roof, cylindrical metallic-capped grain silo (`GrainSilo`), wind pump tower (`FarmWindPump`), wooden paddock fences, golden hay bales, and tilled crop rows.
   - Place **`Fazenda`** on the scenic South-East hill terrace (e.g. `(340, get_terrain_height(340, 260), 260)`) plus a second smaller **`NorthOrchardBarn`** / rural outpost at `(-420, get_terrain_height(-420, -290), -290)`, plus hillside rock outcrops and additional scattered rural trees.
   - Ground **every** placed tree, house, watchtower, crate/barrel/fence prop, capture point, spawn pad (`get_terrain_height`), AA gun, and land vehicle to `get_terrain_height(x, z)` cleanly!

- [ ] **Step 1:** Create `vfx_shaders/toon_sky.gdshader` and verify shader syntax + cloud layers.
- [ ] **Step 2:** Add `BuildingMeshBuilder.build_river_bridge(...)`, `build_river_dock(...)`, and `build_farm_complex(...)` in `maps/building_mesh_builder.gd` ensuring `TRANSPARENCY_DISABLED` on opaque parts and outward winding (`bad_vol == 0`).
- [ ] **Step 3:** Implement `get_terrain_height(x, z)`, `get_river_center_x(z)`, closed `SculptedTerrain` trimesh generation, river bridges/docks/boats, shifted boulevard houses, `Fazenda`, and terrain-grounded trees/props/vehicles/spawns in `maps/map_seaside_frontline.gd` + update `MainGame` spawn grounding if needed.
- [ ] **Step 4:** Update/add comprehensive verification tests in `tests/test_runner.gd` (sky clouds shader, hill height variance `>= 8m`, continuous North-to-South river depth `<= -2.5m` & bridge clearance `>= 4.5m`, `>= 4` boats in central river + `>= 6` harbor boats, `Fazenda` landmark, `bad_vol == 0`, `bad_trans == 0`, `0` blocked spawns/runways).
- [ ] **Step 5:** Run `--headless --import --quit`, `--headless res://tests/test_runner.tscn --quit`, and `--verbose res://tests/test_runner.tscn --quit` (Forward+), inspect render/test output, commit.

---

### Task 7: Dynamic 4-Prong BFH Crosshair, Over-Shoulder Shot Convergence, Crisp Bullet Icon & Unclipped Bottom HUD

**Files:**
- Modify: `vfx_shaders/cartoon_assets.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `entities/characters/hero_camera.gd`
- Modify: `entities/weapons/weapon_base.gd`
- Modify: `entities/weapons/hitscan_weapon.gd`
- Modify: `entities/weapons/projectile_weapon.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **Fix Clipped Bottom Hotbar (`ui/hud_controller.gd`):**
   - Increase `_hotbar_hbox` vertical room and lift its bottom edge cleanly inside screen bounds (e.g. `offset_top = -110.0`, `offset_bottom = -8.0` anchored to bottom center, `clip_contents = false`).
   - Compact skill upgrade `+` buttons (`custom_minimum_size = Vector2(36, 18)` instead of unstyled default height ~31px, tight font size `12`) and keep slot box `42x42` + crisp hotkey label (`1`, `2`, `3`, `4`, `5/E`, `6/Q`, `7`, `8`, `9`, `Z/0`, `X`, `V`) so the full hotkey label row is **100% visible with >= 6px bottom padding** at `1280x720` and `1920x1080` even when `upg` upgrade buttons are visible!
2. **Fix Crooked Bottom-Right Ammo Icon & Alignment (`vfx_shaders/cartoon_assets.gd` + `ui/hud_controller.gd`):**
   - Redesign `CartoonAssets._sprite_bullet()` cleanly: crisp vertically centered brass shell casing + pointed copper jacket bullet + rimmed base groove + subtle cartoon highlight & dark outline (`40x52` balanced padding, zero bottom-skewed stub).
   - Vertically align `br_hbox` (`alignment = BoxContainer.ALIGNMENT_END`, `size_flags_vertical = Control.SIZE_SHRINK_CENTER` on `_ammo_icon_rect` with `STRETCH_KEEP_ASPECT_CENTERED`, clean right-aligned text VBox beside it, `offset_bottom = -16.0`) so `31 / Submachine Gun | ∞` and the cartridge icon look crisp and level.
3. **Replace 4×4 Pixel Dot with Dynamic 4-Prong BFH Crosshair (`ui/hud_controller.gd`):**
   - Replace the static `4x4` `ColorRect` dot with a proper dynamic BFH reticle anchored at screen center: 4 sharp outlined bars (`top`, `bottom`, `left`, `right`) with dark `1px` drop/border contrast + tiny center micro-dot, dynamically expanding/contracting gap (`spread_px`) when firing/sprinting/jumping, and hiding when Sniper Scope is open.
4. **Over-Shoulder Crosshair Aim Convergence (`entities/characters/hero_camera.gd` + `entities/weapons/weapon_base.gd` + `hitscan_weapon.gd` + `projectile_weapon.gd`):**
   - Compute the analytical 3D camera ray matching `HeroCamera`'s over-right-shoulder TPS transform (`HeroCamera.compute_aim_camera_transform(hero_pos, aim_yaw, aim_pitch, is_scoped, is_in_vehicle)` -> returns camera origin & forward direction).
   - Add `WeaponBase.get_aim_origin_and_dir(cmd: InputCmd, space_state: PhysicsDirectSpaceState3D = null) -> Dictionary` (keeping 1-arg default compatibility so existing callers/tests still compile & pass!):
     - Traces a ray (`Layer 1 | Layer 8 | Layer 2` excluding `owner_hero` and occupied vehicle) along the **shoulder camera's exact center-screen ray** from camera origin out to `180.0m` (fallback `cam_origin + cam_dir * 180.0` if sky) to find `crosshair_target: Vector3`.
     - If `owner_hero` is scoped in 1st-person Sniper mode, fire straight along the camera ray from eye origin; otherwise compute muzzle/weapon origin (`hero_pos + up * eye_offset + right * 0.22 - fwd * 0.35`) and aim vector `(crosshair_target - weapon_origin).normalized()`! Ensure close targets (< 3m right in front of camera) clamp cleanly forward so gun never shoots backward.
   - Update `HitscanWeapon._fire_impl` and `ProjectileWeapon._fire_impl` to pass `space_state` into `get_aim_origin_and_dir(cmd, space_state)` so **both client VFX and authoritative server hitscan/rockets hit the exact world point under the center screen crosshair**!

- [ ] **Step 1:** Update `_sprite_bullet` in `vfx_shaders/cartoon_assets.gd`.
- [ ] **Step 2:** Fix `_hotbar_hbox`, `br_hbox`, and replace the pixel dot with the dynamic 4-prong BFH crosshair in `ui/hud_controller.gd`.
- [ ] **Step 3:** Add deterministic shoulder-camera ray math in `entities/characters/hero_camera.gd` and implement crosshair convergence in `entities/weapons/weapon_base.gd`, `hitscan_weapon.gd`, and `projectile_weapon.gd`.
- [ ] **Step 4:** Add verification tests in `tests/test_runner.gd` verifying: hotbar key labels global rects fit cleanly above `viewport_h` with `upg.visible = true`; dynamic 4-prong crosshair nodes exist & expand on spread; over-shoulder weapon shot from `(0, y, 0)` converges onto a target placed directly along the right-shoulder camera crosshair ray (at both `12m` and `65m`)!
- [ ] **Step 5:** Run `--headless --import --quit`, `--headless res://tests/test_runner.tscn --quit`, and Forward+ test runner, commit.

---

### Task 8: Punchy Audible Weapon SFX w/ Priority Pool & Anti-Wallhack Bot AI + Solid Wall Ray Guard

**Files:**
- Modify: `audio/sound_synthesizer.gd`
- Modify: `core/main_game.gd`
- Modify: `core/ai/bot_controller.gd`
- Modify: `core/network/lag_compensator.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **Audible Weapon & Combat SFX (`audio/sound_synthesizer.gd` + `core/main_game.gd`):**
   - Boost procedural gunshot waveform peaks cleanly (`0.78–0.92` peak before clamp, crisp crack/thump envelope per weapon class: SMG punchy pop, Heavy MG bassy chatter, Shotgun booming scatter, Sniper sharp crack, Pistol crisp snap, Bazooka ignition whoosh, Explosion deep low-end thump) and raise local gunshot bus playback from `-18.5 dB` to a clean audible `-4.5 dB` (respecting user `sfx_volume` slider cleanly).
   - Split audio playback pool into **`_local_sfx_pool` (8 players, dedicated to local player shots, hits, footsteps/jumps, skills, reload, UI)** and **`_world_sfx_pool` (12 players, distance-culled `<= 75m` and distance-attenuated in dB)** with per-emitter rate limiting (`_remote_sfx_cooldowns`), so 23 bots shooting across the map NEVER silence or overwrite the local player's weapon audio!
   - Wire `play_sfx(..., is_local_priority: bool, world_pos: Vector3)` in `MainGame` shot VFX handlers so local hero shots always use priority pool and nearby bot/remote shots attenuate realistically with distance.
2. **Bot Anti-Wallhack LOS & Humanized Aim (`core/ai/bot_controller.gd`):**
   - Implement `has_line_of_sight(space_state: PhysicsDirectSpaceState3D, target: HeroCharacter) -> bool` casting a `PhysicsRayQueryParameters3D` with `collision_mask = 1` (World/Walls/Terrain), `hit_from_inside = true`, `exclude` empty (or hero/vehicle if needed) from bot eye height (`global_position + Vector3(0, 1.55, 0)`) to target chest height (`target.global_position + Vector3(0, 1.25, 0)`).
   - Bots **cannot acquire or fire at** any enemy when `has_line_of_sight(...) == false` (no shooting or aiming through houses/walls/hills!). Retain brief `memory_timer` (`<= 0.8s`) only for movement pursuit toward last-seen position — **never fire** when LOS is blocked!
   - Add realistic bot reaction time (`0.22–0.38s` on newly spotted target), distance-scaled angular aim jitter/sway (`~0.032–0.060 rad`), and burst/pause cadence (`0.45–0.85s` burst followed by `0.25–0.45s` pause) so bots miss realistically like real players.
3. **Solid Wall Ray Guard (`core/network/lag_compensator.gd`):**
   - Set `query.hit_from_inside = true` on `intersect_ray` inside `trace_hitscan` and `trace_ballistic_arc` and ensure `world_mask` cleanly collides with Layer `1` walls/buildings/terrain even at close contact range, eliminating shots clipping through house walls.

- [ ] **Step 1:** Upgrade waveform synthesis & dual `_local_sfx_pool` / `_world_sfx_pool` priority channels + volume APIs in `audio/sound_synthesizer.gd` and wire distance/priority calls in `core/main_game.gd`.
- [ ] **Step 2:** Add `PhysicsRayQueryParameters3D` wall LOS guard (`has_line_of_sight`), target reaction delay, burst cadence, and aim inaccuracy spread in `core/ai/bot_controller.gd`.
- [ ] **Step 3:** Add `hit_from_inside = true` wall clipping protection in `core/network/lag_compensator.gd`.
- [ ] **Step 4:** Add automated tests in `tests/test_runner.gd` verifying: (a) local SFX priority channel stays uninterrupted under 24 concurrent bot shots and shot buffer RMS energy `>= 0.20`; (b) a bot behind a Layer-1 `StaticBody3D` house wall reports `has_line_of_sight == false` and refuses to fire (`BTN_FIRE == 0`); (c) bot aim spread exhibits measurable angular variance across shots; (d) `LagCompensator` stops a hitscan ray completely at a solid wall between shooter & target.
- [ ] **Step 5:** Run tests (`--headless` & Forward+), verify `0` failures, commit.

---

### Task 9: 1s Parachute Fall Delay, Freefall & Non-Sliding Collapse Death Animations, Explosive Knockback Overhaul & Back-View Hero Silhouette Polish

**Files:**
- Modify: `entities/characters/hero_character.gd`
- Modify: `entities/characters/hero_mesh_builder.gd`
- Modify: `entities/weapons/projectile_entity.gd`
- Modify: `entities/skills/soldier_skills.gd`
- Modify: `maps/map_seaside_frontline.gd` or `core/combat/destructible_prop.gd` (check explosive barrel friendly fire / knockback!)
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **Parachute 1.0s Fall Delay & Skydiving Freefall Animation (`entities/characters/hero_character.gd`):**
   - Add `const PARACHUTE_MIN_FALL_TIME: float = 1.0` and `@export var _airborne_fall_time: float = 0.0`.
   - In `simulate_movement`, when grounded/swimming/in vehicle/defeated reset `_airborne_fall_time = 0.0`. While airborne, only accumulate `_airborne_fall_time += delta` when `velocity.y < -0.5` (downward fall after jump apex; resets to `0.0` on jump takeoff).
   - Update `can_open_parachute()` AND jump-held auto-open logic to require `_airborne_fall_time >= PARACHUTE_MIN_FALL_TIME` (and `_distance_to_ground() > 1.8`). Jumping on flat ground (`apex ~1.76m`, downward time `~0.42s`) can **never** trigger parachute! Jumping off cliffs/towers/planes opens cleanly after `>= 1.0s` of freefall!
   - Also expose HUD/key prompt only when `can_open_parachute()` is true (`[ESPAÇO] Abrir Paraquedas` subtle non-intrusive prompt in `HUDController`? Keep HUD clean — or set `can_open_parachute()` cleanly).
   - In `_animate_character(delta)`: when airborne & descending past `0.35s` without parachute (`_airborne_fall_time >= 0.35 and not is_parachuting`), pose hero in a clear **Skydiving Freefall** (forward-arched upper torso, outstretched wide arms & splayed trailing legs with brisk wind flutter increasing past `1.0s`).
2. **Walk Animation & Non-Sliding Collapse Death Animation (`entities/characters/hero_character.gd`):**
   - Upgrade walking/running gait (`_walk_phase`) with smoother counter-rotated upper-body twist, distinct stride leg bend & arm carry sway, and remove bouncy spring vertical hop (`_animate_character` bob reduced from `0.06m` to `<= 0.012m`).
   - Fix **Sliding Kneeling Death**: on entering `is_defeated`, zero `velocity.x` and `velocity.z` immediately (`velocity.x = 0.0; velocity.z = 0.0` inside `simulate_movement` during `is_defeated`, applying only gravity & floor snap so defeated corpses **never slide horizontally**!).
   - Upgrade defeat pose animation (`defeat_timer` / `_defeat_elapsed` progression): quick slump onto knees while raising white surrender flag, transitioning into a **full side/forward ground collapse** (torso pitches `-1.15 rad` onto terrain, head bows, left arm rests on ground, right arm weakly waves white surrender flag above ground!).
3. **Explosives Knockback Overhaul — Self-Knockback & Enemies Only, ZERO Friendly Fire (`projectile_entity.gd`, `soldier_skills.gd`, `destructible_prop.gd`, `hero_character.gd`):**
   - Check `DestructibleProp` (red explosive barrel) + `ProjectileEntity` + `SoldierSkills` (`BLASTING_STRIKE`):
     - Skip teammates strictly: `if h.team == owner_team and h.entity_id != owner_id: continue` (zero friendly damage AND zero friendly knockback).
     - For `h.entity_id == owner_id` (self-explosion from Bazooka / Tank / Grenade / TNT / Keg): **apply `0` self-damage (`dmg = 0`)** AND **always apply full radial self-knockback** (even when `dealt == 0`!) so rocket jumping and blasting near walls visibly launches the shooter safely!
     - For enemies (`h.team != owner_team`): deal damage AND always apply strong visible knockback (`apply_knockback`).
   - Enhance `HeroCharacter.apply_knockback(impulse: Vector3)` & `simulate_movement`:
     - Ensure explosion knockback always lifts slightly (`if impulse.y < 4.5 and horizontal_speed > 3.0: impulse.y = maxf(impulse.y, 4.8)`), sets a short knockback traction lock `_knockback_stun_timer = 0.38`, disables `apply_floor_snap()` while `_knockback_stun_timer > 0.0` or `velocity.y > 0.5`, and dramatically lowers ground friction decay (`lerpf(..., 2.2 * delta)` during `_knockback_stun_timer` instead of `16.0 * delta`) so enemies & shooter visibly fly backward and arc through the air!
4. **Back-View Stylized Hero Silhouette Refinement (`entities/characters/hero_mesh_builder.gd`):**
   - Refine rear view silhouette where TPS camera looks 95% of the time: sculpted broad deltoid/shoulder bevel transition (`build_torso_mesh` & `build_shoulder_cap` / arm socket overlap), crisp lower coat split / waist cinch contrast (`vertex_color` subtle lower-hem AO & belt overhang shadow), deeper rear helmet brim flange (`build_helmet_mesh`), and cleaner backpack strap wrapping (`build_backpack_mesh`). Zero negative volume lofts & IK error stays `0.000m`.

- [ ] **Step 1:** Read `core/combat/destructible_prop.gd` briefly so barrel explosions follow the exact same zero-friendly-fire / self-knockback contract.
- [ ] **Step 2:** Update `HeroCharacter` (`_airborne_fall_time`, 1s parachute delay, freefall pose, crisp walk without vertical bounce, non-sliding collapse death, knockback traction lock & lift preservation) in `entities/characters/hero_character.gd`.
- [ ] **Step 3:** Update `ProjectileEntity`, `SoldierSkills`, and `DestructibleProp` to enforce zero friendly fire, zero self-damage, and strong radial knockback on enemies & shooter.
- [ ] **Step 4:** Refine back-view torso/helmet/shoulder/backpack silhouettes in `entities/characters/hero_mesh_builder.gd`.
- [ ] **Step 5:** Update/add tests in `tests/test_runner.gd` verifying: (a) flat jump (`t < 1.0s` fall) returns `can_open_parachute() == false`, whereas `>= 1.0s` fall (`_airborne_fall_time = 1.05`) returns `can_open_parachute() == true`; (b) defeated hero with pre-death `velocity = Vector3(12, 0, -8)` zeroes horizontal sliding (`< 0.05m` drift across 10 ticks) and plays collapse rotation; (c) Bazooka/Grenade/TNT/Barrel deal `0` self-damage & `0` teammate damage while imparting `> 6 m/s` visible displacement knockback to both shooter and enemies after 10 simulation ticks; (d) hero rigs maintain `< 0.025m` IK error and `0` inverted lofts.
- [ ] **Step 6:** Run `--headless` and Forward+ test suites, verify `0` failures, commit.

---

### Task 10: Jitter-Free Interpolated Movement/Camera ("No Pulinhos"), Strict Network Packet Sequencing, & Polished Multi-Screen BFH Menus

**Files:**
- Modify: `entities/characters/hero_character.gd`
- Modify: `entities/characters/hero_camera.gd`
- Modify: `core/network/network_manager.gd`
- Modify: `core/network/net_serializer.gd` (only if adding clean ack/sequence header field cleanly within MTU)
- Modify: `core/main_game.gd`
- Modify: `ui/class_select_menu.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **Eliminate Camera-vs-Physics "Pulinhos" (`hero_character.gd` & `hero_camera.gd`):**
   - Decouple `HeroCamera` vertical/world tracking from raw 60Hz physics `self.global_position`: have `HeroCharacter` update `visual_root.global_position` (interpolated between `_prev_phys_pos` and `_curr_phys_pos` plus smooth exponential `_pred_error_offset` decay!) and have `HeroCamera` (`top_level = true` or tracking `visual_root.global_position` cleanly inside `_process`) follow `visual_root.global_position` smoothly with gentle vertical step smoothing on slopes/hills, completely removing 60Hz-vs-render micro-stutter and walking hop bounce!
   - Replace snapping in `HeroCharacter.reconcile_with_server`: for small reconciliation errors (`0.06m..1.8m`), accumulate into `_pred_error_offset` and decay exponentially over `0.12s` on `visual_root` while keeping physics authoritative! (Keep instant snap for teleport > `4.0m` or boarding/exiting vehicles).
2. **Strict Network Packet Sequencing & Anti-Reorder Handling (`core/network/network_manager.gd` & `core/main_game.gd`):**
   - Track `_peer_last_input_tick: Dictionary` and `_peer_input_seq_stats: Dictionary` on server in `NetworkManager`. Reject out-of-order/stale duplicate packets (`cmd.tick <= last_tick`) deterministically before pushing to `peer_input_buffers`, clamping unreasonable forward bursts while keeping `InputRingBuffer` continuous across minor packet loss (repeating last directional state with decayed edge triggers only if buffer misses a tick, never warping).
   - Reset peer sequence trackers cleanly on peer join/disconnect/shutdown.
3. **Polished Multi-Screen BFH Menus & Pause/Settings Overlay (`ui/class_select_menu.gd` + `core/main_game.gd`):**
   - Transform `ClassSelectMenu` from a single cramped dark panel into a vibrant, BFH-styled **Multi-Screen Interface**:
     - **Screen 1 — Main Hub (`HubPage`):** Stylized War Champions header banner, 3 prominent mode cards (`Treino Offline 12v12 Bots`, `Multiplayer Online`, `Configurações / Controles`), plus clear server connection drawer (`IP / Domínio`, `Porta UDP (7777)`, quick preset buttons `Localhost (127.0.0.1)` / `Servidor Dedicado`, and `Criar Sala (Host)` vs `Entrar na Sala`), with clear validation/error status label (`status_label`).
     - **Screen 2 — Faction & Class Armory (`ArmoryPage`):** Clean 2-faction (`National Army` vs `Royal Army`) toggle cards + 3 distinct Class cards (`Soldier`, `Gunner`, `Commando`) clearly showing **only that class's exclusive weapons & 3 unique skills** + `HP / Velocidade` bars + `ENTRAR NA BATALHA` button (matching visual art direction: warm gold trim, olive/slate/royal accents, rounded cartoon panels).
     - **Screen 3 — Options / Controls & ESC In-Game Pause Overlay (`SettingsPanel`):** Master Volume, SFX Volume, Music Volume sliders wired to `SoundSynthesizer`, Mouse Sensitivity slider wired to `HeroCamera`, Music Mute toggle, controls cheat-sheet (`WASD, Espaço [Paraquedas 1s], E [Veículos], R [Recarregar], F8 [Simular Lag], M [Música]`), and `Voltar ao Menu` button when in-match.
   - Preserve all public signals (`play_offline_bots_requested`, `host_online_requested`, `join_online_requested`, `deploy_requested`, `team_selected`, `class_selected`) and helper methods so existing automated tests & multiplayer flow work seamlessly!

- [ ] **Step 1:** Smooth visual interpolation, `_pred_error_offset` reconciliation, and camera tracking separation in `entities/characters/hero_character.gd` and `entities/characters/hero_camera.gd`.
- [ ] **Step 2:** Add strict monotonic `cmd.tick` sequence validation & jitter tolerance in `core/network/network_manager.gd` and wire cleanly in `core/main_game.gd`.
- [ ] **Step 3:** Rebuild `ui/class_select_menu.gd` with Hub/Armory/Settings multi-screen navigation + in-game ESC pause/settings overlay wired to `SoundSynthesizer` & `HeroCamera` in `core/main_game.gd`.
- [ ] **Step 4:** Add verification tests in `tests/test_runner.gd` verifying: (a) smooth reconciliation updates `_pred_error_offset` cleanly without abrupt visual jumps under `< 1.5m` divergence and camera tracks interpolated `visual_root`; (b) `NetworkManager` drops stale/out-of-order `cmd.tick` packets while accepting strictly increasing ticks; (c) multi-screen `ClassSelectMenu` transitions cleanly across Hub -> Armory -> Deploy and emits `play_offline_bots_requested`, `host_online_requested`, `join_online_requested` + volume/sensitivity settings apply cleanly.
- [ ] **Step 5:** Run full verification (`--headless --import --quit`, `--headless res://tests/test_runner.tscn --quit`, `--verbose res://tests/test_runner.tscn --quit` Forward+, live 2-process ENet handshake + client input ack + vehicle freeze check on port `7805` + `--server --port=7806` startup check), commit.
