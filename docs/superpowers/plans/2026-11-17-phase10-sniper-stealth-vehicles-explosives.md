# Phase 10: Sniper Hitscan & Hitbox Precision, Poisoned Blade, Proximity Stealth, Team-Wide Sixth Sense, Water Submersion Block, Explosive Splash/Knockback Overhaul & New Vehicles (Motorcycle + Armored MG APC)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Fix all 8 user-reported combat, skill, vehicle-water, and explosive issues, and add two new 2-seat cooperative vehicles (Motorcycle & Armored MG Carrier).

## Global Constraints
- **Strict Static Typing:** All GDScript variables, parameters, and return types must be explicitly typed.
- **No Existing Test Regressions:** All 391 existing tests in `tests/test_runner.tscn` must continue to pass (`0 failed`), plus new Phase 10 assertions covering all 8 items.
- **Zero Performance Regression:** Reuse cached materials/primitives in `VehicleMeshBuilder` and `StatusEffectsVFX`.

---

### Task 1: Sniper Hitbox/Hitscan Precision, Poisoned Blade, Proximity Stealth & Team-Wide Sixth Sense (Items 1, 2, 3, 7)

**Files:**
- Modify: `core/network/network_manager.gd`
- Modify: `core/network/lag_compensator.gd`
- Modify: `core/main_game.gd`
- Modify: `entities/weapons/weapon_base.gd`
- Modify: `entities/weapons/hitscan_weapon.gd`
- Modify: `entities/skills/commando_skills.gd`
- Modify: `entities/skills/status_effect_container.gd`
- Modify: `vfx_shaders/hero_cloak_shader.gdshader`
- Modify: `vfx_shaders/status_effects_vfx.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `core/ai/bot_controller.gd`

**Requirements:**
1. **Item 1 — Sniper Accuracy, Range, Lag Rewind & Hitbox Alignment:**
   - In `core/network/network_manager.gd:get_view_interp_tick_delta()`: when `is_server_authority()` is `true` (Solo Bot mode or Host), return `0` instead of `6` so server-authoritative local/host shots never rewind moving enemy hitboxes 100ms (`~0.65m`) behind their rendered position. Only return `clampi(interp_ticks, 0, 65535)` when `not is_server_authority()` (remote ENet client).
   - In `core/network/lag_compensator.gd:_compute_hero_bounds(hero)`: align hitbox dimensions with the actual 3D visual rig in both standing and crouching states:
     - `var r: float = maxf(hero.capsule_radius, 0.46)` (so shots hitting shoulders, arms, or coat edges register reliably; Gunner remains `0.54`).
     - When standing (`not hero.is_crouching`): `body_bottom = h_pos + Vector3(0.0, r, 0.0)`, `body_top = h_pos + Vector3(0.0, 1.55, 0.0)`, `head_center = h_pos + Vector3(0.0, 1.66, 0.0)`, `head_radius = 0.30`.
     - When crouching (`hero.is_crouching`): visual head is around `y = 1.35..1.55` (`_hips_pivot.y = 0.50 + 0.04 + 0.63 + 0.21`), so set `body_bottom = h_pos + Vector3(0.0, r, 0.0)`, `body_top = h_pos + Vector3(0.0, 1.18, 0.0)`, `head_center = h_pos + Vector3(0.0, 1.34, 0.0)`, `head_radius = 0.30`.
   - In `entities/weapons/weapon_base.gd`:
     - For `WeaponKind.SNIPER`: increase `max_range_m = 1500.0` (was `360.0`), `falloff_start_m = 120.0`, `falloff_end_m = 400.0`.
     - In `get_aim_origin_and_dir()`: change `convergence_range` upper clamp from `260.0` to `maxf(260.0, max_range_m)` (`var convergence_range: float = clampf(spring_len + maxf(max_range_m, 30.0), spring_len + 2.0, maxf(260.0, max_range_m))`).
   - In `core/main_game.gd:_physics_process`: before stepping skills and weapons for the local host player (`if hero.is_local_player and not hero.is_bot and hero.hero_camera != null:`), sync `hero.latest_server_input.aim_yaw = hero.hero_camera.yaw`, `hero.latest_server_input.aim_pitch = hero.hero_camera.pitch`, and `hero.latest_server_input.view_interp_tick_delta = 0` so flick-shots use the exact current frame's camera aim.

2. **Item 2 — Commando Poisoned Blade Skill & Melee Reliability:**
   - In `entities/weapons/weapon_base.gd`:
     - For `WeaponKind.KNIFE`: increase `max_range_m = 3.8` (was `2.9`), `falloff_start_m = 3.6`, `falloff_end_m = 4.0`.
     - In `_apply_archetype_modifiers()`: allow `is_melee` weapons to also receive `ARCHETYPE_FAST_SHORT` (`fire_interval = base_fire_interval * 0.72`, `damage_max = base_damage_max * 0.85`, `damage_min = damage_max`) and `ARCHETYPE_SLOW_LONG` (`fire_interval = base_fire_interval * 1.25`, `damage_max = base_damage_max * 1.28`, `damage_min = damage_max`).
   - In `entities/skills/commando_skills.gd`: when activating `slot_idx == 2` (`Poisoned Blade`), set duration `8.0 + float(rank)` (`13.0s` at Rank 5) and DPS `10.0 + float(rank) * 3.0` (`25.0` DPS at Rank 5), AND if `owner_hero.weapons.size() > 1 and (owner_hero.weapons[1] as WeaponBase).weapon_kind == WeaponBase.WeaponKind.KNIFE`, automatically switch `owner_hero.switch_weapon_slot(1)` and `cmd.selected_weapon_slot = 1` so the Commando immediately equips the poisoned knife!
   - In `entities/weapons/hitscan_weapon.gd:fire_server`:
     - If `is_melee` (`weapon_kind == WeaponKind.KNIFE`) and `target_id < 0`, perform a melee cleave fallback across `heroes_by_id`: find the closest living enemy within `max_range_m + 0.55` (`4.35m`) of `owner_hero.global_position` whose horizontal direction from `owner_hero` has `dot >= 0.45` (`~63°` half-angle) with horizontal `shot_dir` and is not enclosed in a vehicle, and set `target_id = best_melee_enemy.entity_id`, `hit_pos = best_melee_enemy.global_position + Vector3(0.0, 1.15, 0.0)`.
   - In `entities/skills/status_effect_container.gd`:
     - In `apply_burn` and `apply_poison`: call `_sync_flags()` immediately at the end of both functions so `SNAP_POISONED` / `SNAP_BURNING` and client green/orange visuals activate on the exact hit frame!
     - In `entities/weapons/hitscan_weapon.gd:_apply_hero_hit`: when `weapon_kind == WeaponKind.KNIFE` and `owner_hero.status_effects.has_poisoned_blade()`, after calling `victim.status_effects.apply_poison(...)`, also deal an immediate initial poison tick `var init_pdmg: int = maxi(1, int(roundf(owner_hero.status_effects.get_poison_dps() * 0.5)))` via `victim.apply_damage_server(init_pdmg, owner_hero.entity_id, false, false, true)`, add `init_pdmg` to `dmg`, and spawn a green poison cloud burst `StatusEffectsVFX.spawn_cartoon_burst(owner_hero.get_parent(), victim.global_position + Vector3(0.0, 1.1, 0.0), "heal", 0.85)`.

3. **Item 3 — Commando Stealth Disappearing / Revealing When Approaching Enemies:**
   - In `entities/skills/commando_skills.gd`: set `var detect_r: float = maxf(9.0, 12.0 - float(rank - 1) * 0.5)` (`10.0m` at Rank 5, `12.0m` at Rank 1).
   - In `entities/skills/status_effect_container.gd`: default `var stealth_detection_radius: float = 10.0`.
   - In `vfx_shaders/hero_cloak_shader.gdshader`: change `ALPHA` calculation to:
     `ALPHA = clamp(mix(0.92, 0.20, cloak_amount) + fresnel * 0.35, 0.0, 1.0);`
     so that when `cloak_amount` is low (`0.12` when revealed by proximity or Sixth Sense), the Commando is ~90% opaque with true base colors, while `cloak_amount = 0.65` is translucent ghost cloak.
   - In `vfx_shaders/status_effects_vfx.gd:update_hero_client_visuals`:
     - Add optional parameter `heroes_by_id: Dictionary = {}` and pass `heroes_by_id` from `core/main_game.gd:_process`.
     - Add helper `static func _is_stealthed_hero_near_enemy(hero: HeroCharacter, local_hero: HeroCharacter, heroes_by_id: Dictionary, detect_r: float) -> bool` that checks if any living hero of the opposite team in `heroes_by_id` (or `local_hero` if opposite team) is within `detect_r` (`dist_sq <= detect_r * detect_r`).
     - When `stealthed` is true:
       - If `is_enemy and local_hero != null`:
         - If `marked_enemy or sensed_enemy or dist_sq <= detect_r * detect_r or _is_stealthed_hero_near_enemy(hero, local_hero, heroes_by_id, detect_r)`:
           `vis = not hero.is_scoping`
           `cloak_val = 0.12` (clearly visible in `HERO_CLOAK_SHADER`, satisfying existing test `cloaked_mat.shader == StatusEffectsVFX.HERO_CLOAK_SHADER`!).
         - Else: `vis = false`.
       - Else (`not is_enemy`, i.e. the local Commando player or allied viewer):
         - Check if `hero` is revealed by proximity (`_is_stealthed_hero_near_enemy(hero, local_hero, heroes_by_id, detect_r)`), `marked`, or `sensed` by enemy Sixth Sense (`StatusEffectContainer.is_enemy_sensed_by_team(hero, 1 - hero.team, heroes_by_id)`):
         - If revealed by enemy proximity / mark / sense: set `cloak_val = 0.0` (swapping to opaque `HERO_SHADER` so the Commando player immediately sees their invisibility disappear when approaching within `10.0m` of an enemy, and reappear `cloak_val = 0.55` when backing away!).

4. **Item 7 — Soldier Sixth Sense Works for the Entire Team & Reveals Invisible Commandos:**
   - In `entities/skills/status_effect_container.gd`:
     - Add static helpers:
       - `static func is_pos_sensed_by_team(world_pos: Vector3, viewer_team: int, heroes_by_id: Dictionary, fallback_viewer: HeroCharacter = null) -> bool`: returns `true` if `fallback_viewer` (when on `viewer_team` and having `SNAP_SIXTH_SENSE`) or ANY living hero `ally` in `heroes_by_id` with `ally.team == viewer_team and not ally.is_defeated and ((ally.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0 or (ally.status_effects != null and ally.status_effects.sixth_sense_timer > 0.0))` is within `SIXTH_SENSE_RADIUS` (`55.0m`) of `world_pos`.
       - `static func is_enemy_sensed_by_team(enemy: HeroCharacter, viewer_team: int, heroes_by_id: Dictionary, fallback_viewer: HeroCharacter = null) -> bool`: returns `true` if `enemy != null and not enemy.is_defeated and enemy.team != viewer_team` and `is_pos_sensed_by_team(enemy_pos, viewer_team, heroes_by_id, fallback_viewer)`.
   - In `vfx_shaders/status_effects_vfx.gd:update_hero_client_visuals`: compute `sensed_enemy = is_enemy and local_hero != null and StatusEffectContainer.is_enemy_sensed_by_team(hero, local_hero.team, heroes_by_id, local_hero)`.
   - In `ui/hud_controller.gd:_update_sixth_sense_markers`: use `StatusEffectContainer.is_enemy_sensed_by_team(enemy, _local_hero.team, _heroes_ref, _local_hero)` for enemy heroes and `StatusEffectContainer.is_pos_sensed_by_team(veh.global_position, _local_hero.team, _heroes_ref, _local_hero)` for enemy vehicles so EVERY member of the Soldier's team sees all enemies and Stealthed Commandos detected by ANY allied Soldier's Sixth Sense!
   - In `core/ai/bot_controller.gd`: in `step_ai` and `_find_nearest_visible_enemy`, a stealthed enemy `cand` is also visible to bots if `((cand.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0) or StatusEffectContainer.is_enemy_sensed_by_team(cand, bot_hero.team, heroes_by_id, bot_hero)`.

---

### Task 2: Block Ground Vehicles from Driving in Water & Overhaul Explosive Splash Radius + Knockback (Items 6 & 8)

**Files:**
- Modify: `entities/vehicles/vehicle_base.gd`
- Modify: `entities/weapons/projectile_entity.gd`
- Modify: `entities/skills/commando_skills.gd`
- Modify: `entities/characters/hero_character.gd`

**Requirements:**
1. **Item 6 — Prevent Ground Vehicles (Jeeps, Tanks, Motorcycles, APCs) from Driving Underwater:**
   - In `entities/vehicles/vehicle_base.gd`:
     - Add `var _water_submerge_timer: float = 0.0` (reset to `0.0` in `_respawn_vehicle()`).
     - Add `func is_ground_vehicle() -> bool`: returns `not is_aircraft() and not is_watercraft() and vehicle_type != VehicleType.AA_GUN`.
     - Add `func is_submerged_in_water() -> bool`:
       ```gdscript
       if not is_ground_vehicle():
           return false
       var cur_y: float = global_position.y if is_inside_tree() else position.y
       return cur_y <= HeroCharacter.WATER_LEVEL - 0.35
       ```
     - In `_apply_arcade_drive`: if `is_submerged_in_water()`, zero out `throttle = 0.0` and apply strong water drag `fwd_speed = lerpf(fwd_speed, 0.0, minf(1.0, 14.0 * delta))` so cars and tanks immediately stall upon entering water and cannot drive along the riverbed!
     - In `step_vehicle_server`: if `is_submerged_in_water()`, increment `_water_submerge_timer += delta`; if `(global_position.y if is_inside_tree() else position.y) <= HeroCharacter.WATER_LEVEL - 0.70` or `_water_submerge_timer >= 0.40`, set `hp = 0` and call `_on_destroyed(-1)` so the submerged ground vehicle is destroyed (ejecting occupants to swim) and respawns at its spawn pad! (Else reset `_water_submerge_timer = 0.0`).

2. **Item 8 — Explosive Splash Radius, Self-Occlusion Fix & High-Impact Knockback:**
   - In `entities/weapons/projectile_entity.gd:setup`:
     - `BAZOOKA_ROCKET`: `splash_radius = 8.0` (was `5.5`), `base_damage = 85.0` (was `68.0`), `knockback_force = 19.0` (was `12.0`).
     - `TNT_SATCHEL`: `splash_radius = 9.0` (was `6.5`), `base_damage = 110.0` (was `90.0`), `knockback_force = 22.0` (was `15.0`).
     - `FRAG_GRENADE`: `splash_radius = 7.5` (was `5.0`), `base_damage = 58.0` (was `42.0`), `knockback_force = 17.0` (was `10.0`).
     - `EXPLOSIVE_KEG`: `splash_radius = 9.5` (was `7.0`), `base_damage = 78.0` (was `55.0`), `knockback_force = 21.0` (was `14.0`).
     - `TANK_SHELL`: `splash_radius = 9.5` (was `7.5`), `base_damage = 110.0` (was `95.0`), `knockback_force = 23.0` (was `16.0`).
   - In `entities/weapons/projectile_entity.gd:_detonate()`:
     - Use capsule-aware distance: `var eff_dist: float = maxf(0.0, dist - h.capsule_radius)`. Check `if eff_dist <= splash_radius:`.
     - Fix occlusion ray so curbs, ground slopes, and destructible crates never swallow explosions:
       - Cast from `var ray_from: Vector3 = global_position + Vector3(0.0, 1.05, 0.0)` to `var ray_to: Vector3 = h.global_position + Vector3(0.0, 1.25, 0.0)` with collision mask `1` only (Layer 1 static world, NOT Layer 64 destructible props).
       - Only treat `occ_hit` as blocking if `not occ_hit.is_empty()` and `absf((occ_hit.get("normal", Vector3.UP) as Vector3).y) < 0.45` (i.e. a vertical wall face, never a ground slope or step!).
     - Increase falloff floor to `0.45`: `var falloff: float = clampf(1.0 - (eff_dist / splash_radius) * 0.55, 0.45, 1.0)`.
     - Compute strong upward+outward knockback vector:
       ```gdscript
       var horiz_vec := Vector3(h.global_position.x - global_position.x, 0.0, h.global_position.z - global_position.z)
       var horiz_dir: Vector3 = horiz_vec.normalized() if horiz_vec.length_squared() > 0.001 else Vector3.FORWARD
       var kb_dir: Vector3 = (horiz_dir * 0.78 + Vector3.UP * 0.62).normalized()
       ```
       And for enemies: `var enemy_kb: float = maxf(21.0, knockback_force)`.
   - In `entities/skills/commando_skills.gd:TroopTrapEntity._explode`: increase explosion radius from `5.5` to `7.5` and knockback multiplier from `12.0` to `20.0`.
   - In `entities/characters/hero_character.gd`:
     - In `apply_knockback(impulse: Vector3)`:
       ```gdscript
       func apply_knockback(impulse: Vector3) -> void:
           velocity += impulse
           if impulse.y > 0.2 or impulse.length() > 5.0:
               velocity.y = maxf(velocity.y, maxf(9.2, impulse.y))
           floor_snap_length = 0.0
           _knockback_stun_timer = maxf(_knockback_stun_timer, 0.60)
           knockback_seq = (knockback_seq + 1) & 0xFF
       ```
     - In `_move_and_slide_with_steps`: return immediately after `move_and_slide()` if `_knockback_stun_timer > 0.0 or velocity.y > 1.0` so step-down snapping never pulls a launched character back down to the floor.

---

### Task 3: New 2-Seat Vehicles — Motorcycle (`VehicleMotorcycle`) & Armored MG Carrier (`VehicleAPC`) + Phase 10 Tests (Items 4 & 5)

**Files:**
- Create: `entities/vehicles/vehicle_motorcycle.gd`
- Create: `entities/vehicles/vehicle_apc.gd`
- Modify: `entities/vehicles/vehicle_base.gd`
- Modify: `entities/vehicles/vehicle_mesh_builder.gd`
- Modify: `maps/map_seaside_frontline.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `core/game_cache.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **Extend `VehicleBase` (`entities/vehicles/vehicle_base.gd`):**
   - Add `MOTORCYCLE` and `APC` to `enum VehicleType`:
     ```gdscript
     enum VehicleType {
         JEEP,
         TANK,
         PLANE,
         BOAT,
         AA_GUN,
         MOTORCYCLE,
         APC,
     }
     ```
   - In `get_driver_hero(heroes_by_id: Dictionary) -> HeroCharacter`:
     - First search `seats` for `s.seat_type == SeatType.DRIVER and s.occupant_id >= 0`.
     - Only if the vehicle has no `SeatType.DRIVER` seat at all (such as `AA_GUN`), fall back to `s.seat_type == SeatType.GUNNER and s.occupant_id >= 0`. This ensures on `APC` (which has Seat 0 `DRIVER` and Seat 1 `GUNNER`), Seat 0 drives the chassis while Seat 1 operates the turret!
   - Add helper `func get_gunner_hero(heroes_by_id: Dictionary) -> HeroCharacter`: returns the occupant of the first `SeatType.GUNNER` seat (or `null`).

2. **Item 4 — Create `VehicleMotorcycle` (`entities/vehicles/vehicle_motorcycle.gd`):**
   - `class_name VehicleMotorcycle extends VehicleBase`
   - Constants: `MAX_SPEED = 33.0`, `ACCEL = 48.0`, `STEER_RATE = 2.85`, `LATERAL_GRIP = 16.0`, `IDLE_DRAG = 4.0`.
   - `_setup_vehicle_stats_and_seats()`:
     - `vehicle_type = VehicleType.MOTORCYCLE`, `max_hp = 190`, `hp = 190`, `mass = 420.0`.
     - Seat 0: `_add_seat(SeatType.DRIVER, Vector3(0.0, 0.68, -0.12), false, false, false, "sit")`
     - Seat 1: `_add_seat(SeatType.PASSENGER, Vector3(0.0, 0.76, 0.68), true, true, false, "sit")` (2 seats total: driver + rear passenger who shoots weapons, uses skills, and repairs with Wrench).
   - `_build_vehicle_mesh()`:
     - Hull `BoxShape3D` (`Vector3(1.05, 0.50, 2.55)` at `Vector3(0.0, 0.75, 0.0)`) + 2 rounded wheel sphere colliders (`radius = 0.38` at `(0.0, 0.38, -0.88)` and `(0.0, 0.38, 0.88)`).
     - Call `_apply_built_visuals(VehicleMeshBuilder.build_motorcycle_visuals(_visual_root, team))`.
   - `_drive_physics(driver: HeroCharacter, delta: float, context: Dictionary)`:
     - Drive with `_apply_arcade_drive(delta, cmd, MAX_SPEED, ACCEL, STEER_RATE, LATERAL_GRIP, IDLE_DRAG, 0.60)`, `_assist_curb_climb(throttle, 1.6, 0.50)`, `_process_roadkill(driver, context, Vector2(0.75, 1.55), 5.0)`.

3. **Item 5 — Create `VehicleAPC` (`entities/vehicles/vehicle_apc.gd`):**
   - `class_name VehicleAPC extends VehicleBase` (Blindado com Metralhadora Montada, 2 lugares).
   - Constants: `MAX_SPEED = 21.0`, `ACCEL = 32.0`, `STEER_RATE = 2.15`, `LATERAL_GRIP = 14.5`, `IDLE_DRAG = 4.8`, `MG_FIRE_INTERVAL = 0.095`, `MG_HERO_DMG = 16`, `MG_OBJ_DMG = 22`.
   - `_setup_vehicle_stats_and_seats()`:
     - `vehicle_type = VehicleType.APC`, `max_hp = 420`, `hp = 420`, `mass = 2600.0`.
     - Seat 0: `_add_seat(SeatType.DRIVER, Vector3(-0.45, 0.85, -0.35), false, false, true, "hidden")` (enclosed armored driver).
     - Seat 1: `_add_seat(SeatType.GUNNER, Vector3(0.0, 1.48, 0.35), false, false, false, "stand", true)` (`follow_turret = true`, 360° mounted MG gunner).
   - `_build_vehicle_mesh()`:
     - Hull `BoxShape3D` (`Vector3(2.5, 1.15, 4.6)` at `Vector3(0.0, 1.05, 0.0)`) + 4 wheel sphere skids (`radius = 0.46` at `wx in [-1.1, 1.1]`, `wz in [-1.65, 1.65]`, `y = 0.46`).
     - Call `_apply_built_visuals(VehicleMeshBuilder.build_apc_visuals(_visual_root, team))`.
   - `_drive_physics(driver: HeroCharacter, delta: float, context: Dictionary)`:
     - Drive chassis with `driver`: `_apply_arcade_drive(delta, drv_cmd, MAX_SPEED, ACCEL, STEER_RATE, LATERAL_GRIP, IDLE_DRAG, 0.65)`, `_assist_curb_climb(throttle, 2.5, 0.55)`, `_process_roadkill(driver, context, Vector2(1.35, 2.45), 5.5)`.
     - Mounted MG turret control: `var heroes_by_id: Dictionary = context.get("heroes_by_id", _last_heroes_by_id)`, `var gunner: HeroCharacter = get_gunner_hero(heroes_by_id)`. If `gunner == null`, fall back to `driver` so a solo player driving the APC can also aim and fire the roof MG, while when Seat 1 (`GUNNER`) is occupied, the Gunner has full independent 360° control of the mounted MG!
     - When `active_operator != null and active_operator.latest_server_input != null`: update `turret_yaw = op_cmd.aim_yaw`, `turret_pitch = op_cmd.aim_pitch`, and when `op_cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0`: set `_driver_fire_cd = MG_FIRE_INTERVAL`, compute `muzzle = global_position + Vector3(0.0, 2.15, 0.0) + fire_dir * 2.3`, and call `_fire_ballistic_mg(active_operator, muzzle, fire_dir, 175.0, 9.8 * 0.20, 220.0, MG_HERO_DMG, MG_OBJ_DMG, context)`.

4. **Sculpted Visuals, Map Spawns & HUD:**
   - In `entities/vehicles/vehicle_mesh_builder.gd`: add `build_motorcycle_visuals(visual_root: Node3D, team: int) -> Dictionary` and `build_apc_visuals(visual_root: Node3D, team: int) -> Dictionary` (returning `{"turret": turret_pivot, "barrel": barrel_pivot}` for APC).
   - In `ui/hud_controller.gd:get_vehicle_display_name(v_type: int)`: return `"MOTO"` for `VehicleBase.VehicleType.MOTORCYCLE` and `"BLINDADO"` for `VehicleBase.VehicleType.APC`.
   - In `maps/map_seaside_frontline.gd:_spawn_all_vehicles`: spawn `VehicleMotorcycle` and `VehicleAPC` at Royal Base, National Base, and midfield flags so both factions have immediate access to them.
   - In `tests/test_runner.gd`: add `_test_phase10_all_8_items()` verifying all 8 requirements.
