# War Champions — Phase 3 Combat, Vehicles, Cockpit, Fountain & Weapons Polish Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all 10 Phase-3 defects (`0`–`9`) across shooting alignment & pure hitscan, step climbing, weapon models/icons, vehicle handling, seated character orientation, open-vehicle damage & open-cockpit plane, animated central fountain, vehicle roadkill, zero firing screenshake, and full magazine reload on respawn.

**Architecture:** Keep Godot 4.7.2 server-authoritative tick determinism (`60Hz` simulation), opaque `StandardMaterial3D` (`TRANSPARENCY_DISABLED` on `alpha >= 0.99`), outward CW mesh winding (`_signed_volume_outward_cw > 0`), and UDP `7777`-avoidance in tests. Use shared helpers (`VehicleBase`, `LagCompensator`, `CartoonAssets`, `HeroMeshBuilder`) rather than duplicating logic across classes.

---

### Task 11: Pure Hitscan Firearms, Exact Crosshair Convergence, Zero Firing Screenshake & Respawn Full Reload (Problems 0, 8, 9)

**Files:**
- Modify: `entities/weapons/weapon_base.gd`
- Modify: `entities/weapons/hitscan_weapon.gd`
- Modify: `core/network/lag_compensator.gd`
- Modify: `entities/characters/hero_camera.gd`
- Modify: `entities/characters/hero_character.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `tests/test_runner.gd`

**Exact Requirements & Design:**
1. **Pure Hitscan (Zero Bullet Drop on Firearms — Problem 0):**
   - In `entities/weapons/weapon_base.gd`: set `bullet_gravity_scale = 0.0` on ALL hitscan firearms (`SMG`, `MG`, `SHOTGUN`, `PISTOL`, `SNIPER`, `KNIFE`). Keep gravity ONLY on explosive projectiles (`ProjectileWeapon`: `BAZOOKA`, `TNT` -> `ProjectileEntity`, `VehicleTank` shells, `AAGun` flak, Grenades, Explosive Keg).
   - In `entities/weapons/hitscan_weapon.gd`: trace pure instant linear hitscan via `lag_comp.trace_rewound_ray(...)` (which wraps straight `_trace_segment`, zero gravity arc) and construct straight 2-point `arc_points = [origin, hit_pos]` for `shot_vfx`.
   - In `ui/hud_controller.gd`: remove the bullet-drop holdover elevation hash ticks below the center reticle inside `_ScopeOverlayControl._draw()` since the Sniper is pure pinpoint hitscan.
2. **Exact Crosshair Convergence & First-Shot/Sniper 100% Precision (Problem 0):**
   - In `entities/weapons/weapon_base.gd`:
     - Track first-shot accuracy reset: add `_first_shot_ready(cmd)` / consecutive-fire bloom timer (`_burst_bloom: float = 0.0`, decays rapidly over `0.28s` after stopping fire, increments smoothly per shot up to `1.0`). When `_burst_bloom <= 0.05` (first shot!) OR (`is_sniper` and scoped `cmd.has_button(InputCmd.BTN_AIM)`), use `spread_mult = 0.0` for pinpoint 100% crosshair accuracy on first shot and scoped sniper!
     - In `get_aim_origin_and_dir(cmd, space_state, lag_comp = null, heroes_by_id = {})` (preserve optional args so 1-arg and 2-arg callers stay backwards-compatible!):
       - Exclude `owner_hero.get_rid()`, current occupied vehicle RID, AND any defeated heroes (`collision_layer` also cleared on defeat — see below).
       - Trace from `pivot_pt` along `cam_dir` against BOTH `space_state` (`1 | 2 | 8 | 64`) AND (when `lag_comp != null`) rewound enemy hitboxes at `cmd.view_interp_tick_delta`! Pick the closest hit distance `>= min_dist` (clamp closer hits cleanly forward along `cam_ray`). This guarantees `target_pt` is the exact world/enemy point under the center crosshair pixel even with network lag rewind or strafing targets!
       - Return `origin` (right shoulder when TPS, `cam_origin` when scoped) and `dir = (target_pt - origin).normalized()`.
   - In `entities/characters/hero_camera.gd`:
     - Remove vertical anchor lag (`dy < 0.35` lerp) in `_process()` so `HeroCamera.global_position` stays locked to `target_anchor` without diverging vertically from `HeroCharacter.compute_aim_ray` on stairs/slopes/jumps.
     - Keep `recoil_pitch_offset = 0.0` (no camera pitch shake — see below) so `pivot.rotation.x == pitch` matches `cmd.aim_pitch` at all times.
   - In `entities/characters/hero_character.gd`:
     - Clear `collision_layer = 0` when `is_defeated = true` and restore `collision_layer = 2` on `respawn_at()` so defeated heroes lying on the ground never block live aim/convergence raycasts.
   - In `core/network/lag_compensator.gd`:
     - Expose a clean static or instance helper `find_rewound_ray_hit_distance(shooter, ray_origin, ray_dir, max_dist, view_tick_delta, current_tick, heroes_by_id)` reused by BOTH `_trace_segment` (rewound enemy check) and `WeaponBase.get_aim_origin_and_dir` convergence — zero duplicated loop logic!
3. **Remove Firing Screenshake / Camera Kick (Problem 8):**
   - In `entities/characters/hero_character.gd` (`trigger_weapon_fire_visual`) and `entities/characters/hero_camera.gd` (`add_recoil`): do NOT kick or shake the camera on firing (`recoil_pitch_offset` stays `0.0`, `add_recoil` becomes a no-op / does not move the camera). Keep held weapon visual kick `_weapon_recoil_anim` and crosshair bloom.
4. **Full Magazine Reload on Respawn (Problem 9):**
   - Add `reset_weapons_full()` on `HeroCharacter` setting `w.ammo_in_mag = w.mag_size`, `w.is_reloading = false`, `w.reload_timer = 0.0`, `w.fire_cooldown = 0.0`, and `_burst_bloom = 0.0` on every equipped weapon.
   - Call `reset_weapons_full()` inside `HeroCharacter.respawn_at()` AND inside `HeroCharacter.reconcile_with_server()` when transitioning from `was_defeated == true` to `is_defeated == false` so multiplayer clients and host HUDs both spawn with full magazines on every weapon!
5. **Tests (`tests/test_runner.gd`):**
   - Update `_test_ballistics_and_knockback()` (~line 956) so firearms verify `bullet_gravity_scale == 0.0` (pure hitscan straight ray at 150m+ hits dead center) while Bazooka/Tank Shell retain parabolic drop.
   - Add assertions verifying: (a) first shot SMG/Sniper convergence onto target at `25m` & `110m` with zero drop and zero miss, (b) `trigger_weapon_fire_visual(..., true)` keeps `hero_camera.recoil_pitch_offset == 0.0` (zero firing screenshake), and (c) draining weapons + `defeated -> respawn_at()` restores every equipped weapon to `ammo_in_mag == mag_size` and `is_reloading == false`.

- [ ] Implement Task 11 changes, run headless tests, inspect diff, review with Spec & Quality Reviewer.

---

### Task 12: Step-Climbing, Crisp Arcade Vehicle Handling, Seated Character Rotation & Roadkill (Problems 1, 3, 4, 7)

**Files:**
- Modify: `entities/characters/hero_character.gd`
- Modify: `entities/vehicles/vehicle_base.gd`
- Modify: `entities/vehicles/vehicle_jeep.gd`
- Modify: `entities/vehicles/vehicle_tank.gd`
- Modify: `entities/vehicles/vehicle_boat.gd`
- Modify: `entities/vehicles/vehicle_plane.gd`
- Modify: `tests/test_runner.gd`

**Exact Requirements & Design:**
1. **Hero & Vehicle Step-Climbing ("Degraus" — Problem 1):**
   - In `HeroCharacter` (`entities/characters/hero_character.gd`):
     - Define `const MAX_STEP_HEIGHT: float = 0.50`.
     - Replace raw `move_and_slide()` for active non-defeated grounded movement in `simulate_movement()` with `_move_and_slide_with_steps(delta, wish_dir, grounded)`:
       - Run normal `move_and_slide()`.
       - If horizontal `wish_dir` was active, `(grounded or is_on_floor())`, and a slide collision occurred against a vertical step wall (`absf(normal.y) < 0.35`) where horizontal progress fell short of desired step distance: perform deterministic step-up sweep via `test_move` / `move_and_collide`: lift up `MAX_STEP_HEIGHT` (stopping early on ceiling), advance horizontally by `step_vel * delta` (minimum probe `0.10m` along wish dir), then sweep downward `MAX_STEP_HEIGHT + 0.06` onto walkable floor (`normal.y >= 0.7`). Accept only if horizontal advance is strictly better and lands on valid floor without wedging! Both client prediction & server run identical math.
   - In `VehicleBase`, `VehicleJeep`, `VehicleTank` (`entities/vehicles/`):
     - Add bevelled/rounded wheel/skid `CapsuleShape3D` (or `SphereShape3D`) bogies along the front/rear bottom of Jeep & Tank AND raise the main `BoxShape3D` belly clearance above `y = 0.58m` so low vertical curbs/steps (`0.14m–0.45m` sidewalks, plazas, stair thresholds, bridge lips) contact smooth curved wheels instead of flat vertical hull walls!
     - Add shared `VehicleBase._assist_curb_climb(delta, throttle, max_step := 0.55)`: when moving forward/reverse into a low frontal obstruction (`ray` at `y = 0.16` hits static ground/curb within `1.6m` ahead while `ray` at `y = 0.62` is clear!), gently lift upward velocity/step height so ground vehicles ride cleanly over curbs, sidewalks, stairs, and thresholds!
2. **Crisp Arcade Vehicle Steering & Lateral Grip (Problem 3):**
   - Add shared `VehicleBase._apply_arcade_chassis_drive(delta, cmd, flat_fwd, max_speed, accel, turn_rate, lateral_grip, linear_drag)` used by both `VehicleJeep` and `VehicleTank` (and aquatic variant or direct call in `VehicleBoat`) — no duplicated force/grip math!
   - Decompose horizontal `linear_velocity` into `fwd_speed = linear_velocity.dot(flat_fwd)` and `side_speed = linear_velocity.dot(flat_right)`.
   - Aggressively damp `side_speed` toward `0.0` (`lerpf(side_speed, 0.0, minf(1.0, lateral_grip * delta))` — `Jeep` `12.5`, `Tank` `14.0`, `Boat` `9.5`) so vehicles **carve tightly where you point the nose** instead of drifting sideways like a ship!
   - Responsive throttle/braking/reverse (`Jeep` `MAX_SPEED=28.0, ACCEL=38.0, STEER_RATE=3.2 rad/s` even at low speed; `Tank` crisp neutral pivot turn `2.1 rad/s`, smooth track traction; `Boat` `MAX_WATER_SPEED=24.0, ACCEL=32.0, STEER_RATE=2.7 rad/s` with strong keel grip and crisp deceleration when releasing W/S).
3. **Seated Character Rotates With Vehicle (Problem 4):**
   - In `HeroCharacter` (`entities/characters/hero_character.gd`):
     - Add helper `_resolve_current_vehicle() -> VehicleBase` (using `get_tree().get_nodes_in_group("vehicles")` or cached reference).
     - In `_process()` when `current_vehicle_id >= 0`:
       - Sync `visual_root.global_position = veh.get_seat_world_pos_for_hero(self)` (or `global_position` if destroyed) so there is zero 1-frame lag behind interpolating vehicles on clients!
       - For non-turret Driver/Pilot seats (`not current_seat_can_shoot and current_seat_pose != "hidden"` and not turret gunner — i.e., Jeep driver, Boat driver, Plane pilot): set `visual_root.global_transform.basis = veh.global_transform.basis` so the seated character rotates/pitches/banks **1:1 with the vehicle body**, while `_head_pivot.rotation.y` turns subtly toward `clampf(angle_difference(aim_yaw, veh.rotation.y), -0.45, 0.45)`!
       - For `follow_turret` Gunner seats (AA Gun): align `visual_root.rotation.y = veh.turret_yaw`!
       - For open shooting passengers (`current_seat_can_shoot == true`, Jeep/Boat passengers, Tank rear, Plane wing-riders): align lower-body base with `veh` when idle, or rotate toward `aim_yaw` smoothly while keeping pitch/bank seated upright with `veh.global_transform.basis`!
4. **Reliable Vehicle Roadkill (Problem 7):**
   - Remove the narrow Jeep-only stub in `vehicle_jeep.gd:52-65` and implement shared `VehicleBase._process_roadkill(driver, context, half_extents: Vector2, min_speed: float = 5.5)` called from `VehicleJeep`, `VehicleTank`, `VehicleBoat`, and low-flying `VehiclePlane`!
   - Compute hero position in vehicle local space (`affine_inverse()`), check XY/XZ oriented box overlap (`abs(local_p.x) <= half_extents.x + 0.65`, `abs(local_p.z) <= half_extents.y + 0.85`, `local_p.y >= -0.9 and local_p.y <= 2.4`), `driver != null`, zero friendly fire (`h.team != driver.team`), per-victim `0.45s` impact cooldown, lethal speed-scaled damage (`maxi(int(h.max_hp * 1.25), int(spd * 15.0))`) + dramatic comic ragdoll fling (`apply_knockback`) + hit/kill VFX!
5. **Tests (`tests/test_runner.gd`):**
   - Test hero stepping up a `0.35m` vertical box curb without snagging; test Jeep climbing a `0.32m` curb/step; test Jeep/Boat lateral velocity suppression during sharp turns; test seated Jeep driver `visual_root.rotation.y` follows turning Jeep; test Tank & Jeep roadkill defeating enemy pedestrian at `>= 8 m/s` with zero friendly fire.

- [ ] Implement Task 12 changes, run headless tests, inspect diff, review with Spec & Quality Reviewer.

---

### Task 13: Open-Cockpit Plane, Open-Vehicle Damage, Animated Fountain Streams & Upgraded Weapons/Icons (Problems 2, 5, 6)

**Files:**
- Modify: `entities/vehicles/vehicle_plane.gd`
- Modify: `entities/vehicles/vehicle_boat.gd`
- Modify: `entities/vehicles/vehicle_mesh_builder.gd`
- Modify: `core/network/lag_compensator.gd`
- Modify: `maps/building_mesh_builder.gd`
- Modify: `entities/characters/hero_mesh_builder.gd`
- Modify: `vfx_shaders/cartoon_assets.gd`
- Modify: `tests/test_runner.gd`

**Exact Requirements & Design:**
1. **Only Tank Shields Driver; Open-Vehicle Occupants Take Direct Damage + Plane Open Cockpit (Problem 5):**
   - Set `is_enclosed = false` in `VehiclePlane._setup_vehicle_stats_and_seats()` (Pilot seat!) and `VehicleBoat._setup_vehicle_stats_and_seats()` (Driver seat!). **ONLY** `VehicleTank` driver keeps `is_enclosed = true`!
   - Adjust open-vehicle physics colliders (`VehicleJeep`, `VehicleBoat`, `VehiclePlane`, `AAGun`):
     - Lower hull colliders / split Plane collider (fuselage lower belly `y = 0.25..1.05` + thin wings `BoxShape3D(8.5, 0.42, 2.2)` at `y = 0.86`, nose `z = -2.0` and tail `z = +1.8` leaving the open cockpit bay `z in [-0.7, 0.4], y > 1.05` physically unobstructed!) so bullets aimed at a seated Pilot, Jeep Driver/Passenger, Boat Driver/Passenger, or AA Gunner hit the hero's head/torso directly instead of hitting an oversize hull `BoxShape3D`!
     - Also in `LagCompensator._trace_segment`: if an enemy hero is in an **open** vehicle (`current_vehicle_id >= 0 and not live_h.current_seat_enclosed`) AND the world physics ray hit that exact occupied vehicle (`hit_vehicle_id == live_h.current_vehicle_id`) rather than a solid wall, allow testing upper torso / head hitboxes so open-vehicle occupants are reliably hittable from all angles!
   - In `VehicleMeshBuilder.build_plane_visuals()` (`entities/vehicles/vehicle_mesh_builder.gd`):
     - Remove `CanopyGlass`, `CanopyFrameFront`, `CanopyFrameRear`, `CanopySpineFront`, `CanopySpineRear`, and `CanopySill` completely (no sealed glass dome!).
     - Build a true **open fighter Cockpit**: dark cockpit tub floor & inner sidewalls, quilted/leather coaming bolster ring (`CockpitCoaming`), instrument dial panel + control stick, and a compact angled clear front fighter **Windscreen** (`WindscreenGlass`) ONLY ahead of the pilot (`z ≈ -0.68`) leaving the top and sides completely open with the pilot sitting clearly visible inside!
2. **Animated Water Fountain (`maps/building_mesh_builder.gd` — Problem 6):**
   - In `BuildingMeshBuilder.build_central_fountain()`:
     - Delete the 20 frozen floating `_add_cyl` jet cylinders!
     - Give `LowerWater` and `UpperWater` a custom scrolling/rippling water `ShaderMaterial` (`TIME`-driven concentric ripples, shimmering cyan foam rings & specular sheen) so the pool surface visibly animates!
     - Attach **4 parabolic `GPUParticles3D` water stream emitters** (`FountainJet_0..3`) arching out of the upper bowl (`local_accel = (0, -14, 0)`, radial outward velocity, soft cyan/white foam spherical/quad particles pouring continuously into the lower basin), **1 central upward finial spray emitter** (`FountainPlume`), and **4 splash mist ring emitters** at basin impact points! (Guarded cleanly if needed, `GPUParticles3D` works safely in both Vulkan Forward+ and `--headless` when using standard `ParticleProcessMaterial` + `SphereMesh`/`QuadMesh`).
3. **Upgraded 3D Weapons & Hotbar Weapon Icons (`hero_mesh_builder.gd` & `cartoon_assets.gd` — Problem 2):**
   - In `HeroMeshBuilder.build_weapon_mesh()`: sculpt all 8 weapons with tapered `make_loft` curved stocks, sculpted receivers, trigger guards, bolts, cooling shroud holes/ribs, curved magazines, brass scope lenses on Sniper, iron sights, flared Bazooka venturi + warhead nose, individual bundled dynamite cylinders & brass timer on TNT! Ensure every custom `ArrayMesh` >= 12 faces keeps positive outward CW signed volume and opaque materials keep `TRANSPARENCY_DISABLED`.
   - In `CartoonAssets._sprite_weapon()`: upgrade icons from cramped `48x32` rectangles to sharp **`96x64`** cartoon-outlined shaded silhouettes (distinct iconic BFH shapes with dark 2px outline + metallic/walnut/brass/olive fill & highlight for SMG, MG w/ drum & handle, Shotgun w/ pump & buttstock, Pistol, Sniper w/ brass scope, Commando Knife, Bazooka w/ rocket, TNT dynamite bundle).
4. **Tests (`tests/test_runner.gd`):**
   - Replace old `CanopyGlass` presence check with `CanopyGlass == null` + open cockpit node checks (`CockpitCoaming`, `WindscreenGlass`) + open-vehicle damage integration checks (shooting Plane pilot, Boat driver, Jeep driver deals damage; shooting Tank driver deals 0 direct bullet damage).
   - Add CentralFountain animation check (zero frozen arc cylinders, `LowerWater` animated `ShaderMaterial`, active `GPUParticles3D` water jet emitters!).
   - Verify all 8 `HeroMeshBuilder.build_weapon_mesh` variants + `CartoonAssets._sprite_weapon` (`96x64`, opaque pixels > 0, no runtime errors).

- [ ] Implement Task 13 changes, run full `--headless` and Vulkan Forward+ suites, inspect live scene/screenshots if needed, inspect diff, review with Spec & Quality Reviewer.

---

### Final Gate (Phase 3): Whole-Branch Review, Live Runtime + Screenshot Verification, Merge & Push
- Generate `git diff main..HEAD`, run Final Whole-Branch Reviewer (`Model="pro"`).
- Run `--headless --import --quit`, `--headless res://tests/test_runner.tscn`, `--verbose res://tests/test_runner.tscn` (Vulkan Forward+), dedicated `--server --port=7799`, 2-process ENet `--port=7805`, plus launch & inspect rendered frames if needed to verify CentralFountain & open Plane cockpit & crosshair convergence visually.
- Fast-forward/merge onto `main`, re-run all verification gates after merge, push `origin main`.
