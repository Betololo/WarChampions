# Phase 11: Demolisher Class, Vehicles Overhaul, Gameplay Fixes, COD Hitmarkers & Weapon Animations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Execute continuously without pausing.

**Goal:** Resolve all 7 reported gameplay/visual bugs and add the 4th playable class (**Demolisher**) with its complete 3D character/gear rig, 7 weapons/variants, 5 active skills, COD-style crosshair/hitmarkers, pump/reload animations, and automated verification suite.

**Architecture:** Incremental multi-task execution on branch `feat/phase11-demolisher-vehicles-polish` (branched from Phase 10's green `feat/phase10-sniper-stealth-vehicles-explosives`). Existing fixed-bit `NetSerializer` packets stay backwards-compatible (`INPUT_CMD_BYTES = 15`, 2-bit `class_id` in `WorldSnapshot`, 4 unused bits `1<<12..1<<15` in `u16 active_buffs`). New entities (`FirePatchEntity`, `RiotShieldEntity`, new `ProjectileKind` presets, `FlameWeapon`, `ClassDemolisher`, `DemolisherSkills`) follow existing project patterns (`TroopTrapEntity`, `SkillManager`, `WeaponBase`, `HeroMeshBuilder`).

**Tech Stack:** Godot `v4.7.2-stable` (GDScript strict static typing, headless `--path . tests/test_runner.tscn`), procedural 3D meshes (`HeroMeshBuilder`, `VehicleMeshBuilder`, `CartoonAssets`), ENet RPC + snapshot sync.

## Global Constraints
- Strict GDScript static typing on all variables, parameters, and return types.
- `INPUT_CMD_BYTES` must remain strictly `15` bytes (`test_runner.gd`).
- Map budgets must stay within `MeshInstance3D <= 900`, unique meshes `<= 350`, unique materials `<= 200`.
- Total vehicle count on map must stay `<= 32` (`NetSerializer.pack_world_snapshot`).
- Always run the full Godot headless test suite after every task and confirm `0 failed`.

## Review Focus
1. **Poisoned Blade remote client vs Antidote:** Verify Poisoned Blade removes instant hit bonus (`init_pdmg`), ticks purely at `0.5s` intervals for `6.0s`, resets `_poison_tick_accum` on `cleanse_poison` and `apply_poison`, and is fully cured by Antidote (`Widget 3`).
2. **Ground Vehicle water vanish vs explosion & Boat/APC gunner enforcement:** Verify ground vehicles stall in water, do NOT explode or kill/hurt occupants, wait until `get_occupant_count() == 0`, vanish quietly without explosion VFX/killfeed, and respawn; verify Driver (`Seat 0`) can NEVER fire Boat or APC guns even when `Seat 1` (`Gunner`) is empty, Boat bullets spawn from the bow turret muzzle, APC rear passenger (`Seat 2`) faces backwards (`PI`), and Boat has exactly 3 seats (`Driver`, `Bow Gunner`, `Rear Standing Passenger`).
3. **Freefall timing, articulated crouch, stair/hill fall damage & Gunner Shield+Lifesteal isolation:** Verify freefall animation requires `_airborne_fall_time >= 1.0`, crouching bends articulated knees forward without burying torso or sinking boots below `y = 0`, sliding/hopping small stairs/hills deals `0` fall damage, and `Frenzy Fire` / `I Eat Grenades` / `Bandages` never add to `hero.shield`.
4. **Demolisher flamethrower water rule, sticky arming/destruction & Caber one-shot reset:** Verify flamethrowers (`Flamethrower`, `Fire Breath`, `Fire Starter`) + ground `FirePatchEntity` reset Afterburn duration on new contact, deal `0` dmg/burn in water or within `2.0s` of using `Água` (`Widget 2`); verify `Trapper` stickies cannot detonate before `0.5s`, can be destroyed by enemy gunfire/AoE, and `Stick Grenade` deals `60` AoE + `60` self-dmg once per life until respawn.
5. **Demolisher Skill 3 no timeout + Skill 4 temporary shield cleanup + COD hitmarkers:** Verify Skill 3 (`TNT Rope`) blocks normal shots indefinitely until Left-Click throw, Skill 4 (`Damage->Shield`) removes only the temporary shield earned when its `3.0s` timer expires, Skill 5 triples vehicle damage cleanly across all weapon types, and COD hitmarkers show gray/red/white diagonal ticks around an open center gap.

---

### Task 1: Bugfixes Core — Poisoned Blade Pure DoT, Water Widget Naming, Articulated Crouch / Freefall / Fall Damage & Shield/Lifesteal Guard (Items 1, 3, 7 & Water Item Base)

**Files:**
- Modify: `entities/weapons/hitscan_weapon.gd`
- Modify: `entities/skills/status_effect_container.gd`
- Modify: `entities/skills/skill_catalog.gd`
- Modify: `entities/skills/skill_manager.gd`
- Modify: `ui/class_select_menu.gd`
- Modify: `entities/characters/hero_mesh_builder.gd`
- Modify: `entities/characters/hero_character.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **Item 1 — Poisoned Blade Pure DoT & Antidote Reset:**
   - In `entities/weapons/hitscan_weapon.gd:_apply_hero_hit`: remove the immediate initial poison hit damage (`init_pdmg` / `apply_damage_server` bonus on knife strike). Keep only normal knife melee damage + `victim.status_effects.apply_poison(owner_hero.entity_id, owner_hero.status_effects.get_poison_dps(), 6.0)` + green `"heal"` `"hit_vfx"` cloud so the DoT ticks cleanly over `6.0s` at `0.5s` intervals.
   - In `entities/skills/status_effect_container.gd`: reset `_poison_tick_accum = 0.0` in both `apply_poison()` and `cleanse_poison()` (also reset `_burn_tick_accum = 0.0` in `apply_burn()` / `cleanse_burn_and_grant_immunity()`). Also ensure `apply_burn()` refreshes `burn_timer = maxf(burn_timer, duration)` whenever `duration >= burn_timer` (resetting Afterburn to full `duration` on every new fire contact!) and returns early (`return`) without applying burn if `owner_hero != null and owner_hero.is_in_water` or `fire_immunity_timer > 0.0`.
   - In `entities/skills/status_effect_container.gd:_physics_process`: if `owner_hero.is_in_water` while `burn_timer > 0.0`, immediately extinguish (`burn_timer = 0.0`, `burn_dps = 0.0`, `_burn_tick_accum = 0.0`, `_sync_flags()`).
   - In `entities/skills/skill_catalog.gd`: update Poisoned Blade catalog text (`"duration": "13.0s"`, `"effect_stats": "Envenena por 6.0s (+25 dano/s em ticks de 0.5s)"`), and update Widget 2 display name/description from `"Antifogo"` / `"Roupa Antifogo"` to **`"Água"`** (`"Limpa Afterburn/Fogo e garante imunidade a chamas por 2.0s"`) in `skill_manager.gd` (`widget_names[2] = "Agua"`), `skill_catalog.gd`, and `ui/class_select_menu.gd` (`w_names[2] = "Água"`). Keep internal `BUFF_FIREPROOF` constant and existing test functionality intact.
2. **Item 3 — Freefall Delay (`>= 1.0s`), Articulated Knee Crouch Rig & Realistic Fall Damage:**
   - In `entities/characters/hero_mesh_builder.gd`: add `build_thigh_mesh(thigh_r: float) -> ArrayMesh` (y `0.0` to `-0.35`) and `build_calf_mesh(thigh_r: float) -> ArrayMesh` (y `0.0` to `-0.24`), and register/warm them cleanly while preserving `build_leg_mesh`.
   - In `entities/characters/hero_character.gd`:
     - Add `var _calf_l_pivot: Node3D` and `var _calf_r_pivot: Node3D`. Update `_create_leg_rig` to return `[leg_pivot, calf_pivot]` (`thigh` mesh on `leg_pivot`, `_calf_pivot` at `Vector3(0.0, -0.34, 0.0)`, `calf` mesh + `boot` at `Vector3(0.0, -0.22, 0.0)` on `_calf_pivot`).
     - In `_animate_character(delta)`:
       - Freefall (`is_falling_air`): set `var is_falling_air: bool = (not is_on_floor() and (active_flags & NetSerializer.SNAP_GROUNDED) == 0 and not is_in_water and not is_parachuting and _airborne_fall_time >= 1.0)`.
       - Normal Airborne Jump Pose (`0.0 < _airborne_fall_time < 1.0` or ascending jump): keep `_held_weapon_root.visible = true` (unless enclosed/turret), keep torso upright, slightly tuck knees (`thigh +0.28`, `calf -0.45`) cleanly without entering belly-down skydiving pose!
       - Articulated Crouch Pose (`is_crouching`): `_hips_pivot.position.y` -> `0.52`, `_leg_l_pivot.rotation.x` = `+1.10 + stride * 0.42`, `_leg_r_pivot.rotation.x` = `+1.10 - stride * 0.42`, `_calf_l_pivot.rotation.x` = `-1.45 + stride * 0.20`, `_calf_r_pivot.rotation.x` = `-1.45 - stride * 0.20`, `_torso_pivot.rotation.x` = `aim_pitch * 0.25 + 0.14 - kick * 0.05` (torso leans slightly forward cleanly ABOVE hips, never sinking inside legs, boots flush near `y = 0`). When not crouching/falling, `_calf_l_pivot.rotation.x = maxf(-0.55, -maxf(0.0, -stride) * 0.45)`, `_calf_r_pivot.rotation.x = maxf(-0.55, -maxf(0.0, stride) * 0.45)` for natural walking knee bend.
     - Fall Damage overhaul:
       - Raise `FALL_DAMAGE_THRESHOLD_SPEED = 16.5` (from `13.5`).
       - Add `var _airborne_start_y: float = 0.0` (initialized on spawn/respawn and updated whenever `grounded or is_in_water` to `global_position.y`).
       - In `simulate_movement`: if descending without ground/water, only accumulate `_airborne_fall_time` & `_max_air_fall_speed`, and keep `_airborne_start_y = maxf(_airborne_start_y, global_position.y)` on rising jump apex.
       - On landing (`(grounded or is_in_water) and _was_airborne`): compute `var drop_h: float = _airborne_start_y - global_position.y`. Only apply fall damage if `not is_parachuting and not is_in_water and _max_air_fall_speed > FALL_DAMAGE_THRESHOLD_SPEED and drop_h >= 4.2 and _airborne_fall_time >= 0.72` (`fall_dmg = maxi(5, int(roundf((_max_air_fall_speed - FALL_DAMAGE_THRESHOLD_SPEED) * 6.5)))`). In `_move_and_slide_with_steps`: when successfully climbing/stepping (`valid_floor`), reset `_airborne_fall_time = 0.0` and `_max_air_fall_speed = 0.0` and `_airborne_start_y = global_position.y`.
3. **Item 7 — Shield vs Lifesteal Strict Isolation:**
   - Audit and guard `heal_server(amount: int)` and `StatusEffectContainer` HoT/Frenzy/EatGrenades paths so HP healing ONLY modifies `hp` (up to `max_hp`) and NEVER touches `shield`.
4. **Tests (`tests/test_runner.gd`):**
   - Update `_test_overhaul_net_u32_fall_damage_and_assets` fall test so it supplies realistic `_airborne_start_y = h.global_position.y + 8.0` and `_airborne_fall_time = 1.1` (and also verify a small `2.2m` / `0.5s` stair/hill drop deals `0` fall damage!).
   - Add automated assertions for: Poisoned Blade pure DoT (knife slash deals base melee dmg only without instant poison spike, then ticks `13 dmg` at `0.5s`, Antidote cleanses immediately + resets accum), Freefall animation stays false `< 1.0s` airborne and activates at `>= 1.0s`, Crouch rig lowers hips to `~0.52m` with positive thigh `+X` bend, negative knee `-X` bend, and torso above hips, and Gunner `Hero Shield` + `Frenzy Fire` 4th-hit lifesteal increases `hp` ONLY and leaves `shield` strictly unchanged!

---

### Task 2: Vehicles Overhaul — Silent Water Vanish, Dedicated Gunner Turrets (Boat & APC), Boat 3 Seats & APC Rear Hitch Seat (Item 2)

**Files:**
- Modify: `entities/vehicles/vehicle_base.gd`
- Modify: `entities/vehicles/vehicle_mesh_builder.gd`
- Modify: `entities/vehicles/vehicle_boat.gd`
- Modify: `entities/vehicles/vehicle_apc.gd`
- Modify: `entities/characters/hero_character.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **`VehicleBase` (`entities/vehicles/vehicle_base.gd`):**
   - Add `local_yaw: float = 0.0` field to `SeatSlot` and parameter `p_local_yaw: float = 0.0` (with default `0.0`) on `_add_seat(...)`.
   - Add `func get_occupant_count() -> int` returning count of seats with `occupant_id >= 0`.
   - Add `func _vanish_in_water_and_schedule_respawn() -> void`: sets `is_destroyed = true`, `_respawn_timer = respawn_delay`, `_water_submerge_timer = 0.0`, `hp = 0`, `linear_velocity = Vector3.ZERO`, `angular_velocity = Vector3.ZERO`, `visible = false`, `freeze = true`, `collision_layer = 0`, `destroyed.emit(id, -1)`. Does **NOT** eject with explosion damage, does **NOT** broadcast `"explosion_vfx"` or `"vehicle_destroyed"` killfeed!
   - Update `step_vehicle_server`: when `is_submerged_in_water()`, increment `_water_submerge_timer += delta`; ground vehicles stay immobilized/stalled while occupants remain inside (`throttle = 0.0`, heavy drag); as soon as `(_get_world_y() <= HeroCharacter.WATER_LEVEL - 0.70 or _water_submerge_timer >= 0.40) and get_occupant_count() == 0`, call `_vanish_in_water_and_schedule_respawn()` and `return`.
   - Update `HeroCharacter._sync_seated_visual_orientation()` (`entities/characters/hero_character.gd`): when seated in a non-enclosed non-turret passenger seat with `seat.local_yaw != 0.0` (while not actively firing/aiming, OR facing `seat.local_yaw` offset around vehicle Y axis), orient `visual_root.global_transform.basis` cleanly to `veh.global_transform.basis * Basis(Vector3.UP, seat.local_yaw)`!
2. **`VehicleMeshBuilder.build_boat_visuals` (`entities/vehicles/vehicle_mesh_builder.gd`):**
   - Put the bow twin-MG carriage (`BowMount`, `BowShield`) under a rotating `turret := Node3D.new()` (`name = "Turret"`) at `Vector3(0.0, 1.04, -2.42)`, and put the dual barrels (`BowMG`s) + `Muzzle` under `barrel_piv := Node3D.new()` (`name = "BarrelPivot"`) at `Vector3(0.0, 0.34, -0.10)`. Return `{"turret": turret, "barrel": barrel_piv}` instead of `{}`.
3. **`VehicleBoat` (`entities/vehicles/vehicle_boat.gd`):**
   - **Exact 3 seats:**
     - Seat 0: `_add_seat(SeatType.DRIVER, Vector3(0.0, 0.85, 0.35), false, false, false, "sit")` — Pilot only! Remove all weapon firing from `driver` in `_drive_physics()`.
     - Seat 1: `_add_seat(SeatType.GUNNER, Vector3(0.0, 0.96, -1.95), false, false, false, "stand", true)` — Front bow artillery gunner (`follow_turret = true`), ONLY seat allowed to aim & fire the bow twin-MG! When `gunner != null`, update `turret_yaw` & `turret_pitch` from `gunner.latest_server_input`, compute barrel muzzle directly from `_barrel_pivot.global_transform * Vector3(0.0, 0.0, -0.95)` (or fallback bow turret math `global_transform * Vector3(0.0, 1.38, -2.52) + fire_dir * 1.1` when headless/unmounted), and fire `_fire_ballistic_mg(gunner, muzzle, fire_dir, ...)`.
     - Seat 2: `_add_seat(SeatType.PASSENGER, Vector3(0.0, 0.76, 1.95), true, true, false, "stand")` — Rear deck standing passenger behind the pilot, able to use weapons & skills/items!
4. **`VehicleAPC` (`entities/vehicles/vehicle_apc.gd`):**
   - **Exact 3 seats:**
     - Seat 0: `DRIVER` enclosed (`"hidden"`) — drives chassis ONLY; NEVER operates or fires the roof turret even when Seat 1 (`GUNNER`) is empty (`var operator: HeroCharacter = gunner` ONLY!).
     - Seat 1: `GUNNER` (`follow_turret = true`, `"stand"`) — ONLY operator of the 360° mounted roof MG; muzzle computed from `_barrel_pivot.global_transform * Vector3(0.0, 0.0, -2.35)` (matching `MuzzleCone` at `-2.26` on the barrel pivot, with deterministic fallback `global_position + Vector3(0.0, 1.88, 0.0) + fire_dir * 2.35`).
     - Seat 2: `_add_seat(SeatType.PASSENGER, Vector3(0.0, 0.85, 2.48), true, true, false, "sit", false, PI)` — Rear hitch passenger sitting facing backwards (`PI`), able to use weapons & items!
5. **`HUDController` & `tests/test_runner.gd`:**
   - Ensure `_refresh_seat_diagram` shows `"Piloto"`, `"Artilheiro"`, `"Passageiro"` cleanly for 3-seat Boat & APC.
   - Update Phase 10 tests (`Phase 10.5`, `Phase 10.6`, plus new Phase 11 vehicle tests) to verify all new Boat/APC/water rules.

---

### Task 3: COD-Style Crosshair & Hitmarkers + Weapon Pump / Reload Cycle Animations (Items 5 & 6)

**Files:**
- Modify: `core/main_game.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `entities/characters/hero_mesh_builder.gd`
- Modify: `entities/characters/hero_character.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **COD-Style Crosshair & Hitmarkers (`ui/hud_controller.gd`, `core/main_game.gd`):**
   - In `core/main_game.gd`: add `"killer_id": killer_id` to `"kill_event"` payload (`lines 732-736`), and in `_on_game_event("kill_event", ...)` when `int(payload.get("killer_id", -1)) == NetworkManager.local_peer_id`, call `hud.show_hitmarker(false, true)`.
   - In `ui/hud_controller.gd`:
     - Crosshair arms: keep `_crosshair_top` node present (hidden `visible = false` so `get_node_or_null("Top") != null` test stays valid while COD-style Bottom + Left + Right gray arms render cleanly in `Color(0.76, 0.78, 0.80, 0.92)`!). Keep center dot tiny/clean or minimal gap.
     - Replace the huge center `"X"` blocking targets: keep `_hitmarker_lbl` (`text = ""`) timing synchronized for legacy test compatibility (`_hitmarker_lbl.visible` / `_hitmarker_timer`), AND add 4 rotated crisp diagonal tick lines (`HitDiagTL`, `HitDiagTR`, `HitDiagBL`, `HitDiagBR` at ±45° radiating from `7px` to `15px` around the open center!).
     - Update `show_hitmarker(is_headshot: bool, is_kill: bool = false)`:
       - Kill: `Color.WHITE` (`_hitmarker_timer = 0.24`)
       - Headshot: `Color(1.0, 0.16, 0.14)` (`_hitmarker_timer = 0.20`)
       - Normal hit: `Color(0.76, 0.78, 0.82)` (`_hitmarker_timer = 0.16`)
2. **Weapon Pump / Reload / Cycle Animations (`hero_mesh_builder.gd`, `hero_character.gd`):**
   - Preserve `"name"` and `"base_pos"` per sub-mesh in `HeroMeshBuilder._weapon_cache` (`populate_weapon_root`). Name Shotgun pump forend `"Pump"` (across archetypes `0, 1, 2`), Bazooka rocket/warhead `"Warhead"`, Sniper bolt `"Bolt"`.
   - In `HeroCharacter`: store `_weapon_parts_by_name: Dictionary = {}` (`name -> {"node": MeshInstance3D, "base_pos": Vector3}`) and add `_cycle_anim_timer: float`, `_cycle_anim_duration: float` (triggered on `trigger_weapon_fire_visual` AND read live from local `weapons[selected_weapon_slot].cooldown_timer` / `is_reloading`!).
   - In `_pose_held_weapon_and_arms`:
     - Shotgun (`WeaponKind.SHOTGUN`): when cycling after a shot or reloading, slide `"Pump"` backward (`+Z` `+0.11m`) and forward along the barrel while pulling `_forearm_l` / left hand IK smoothly with it!
     - Bazooka / Pirate Cannon (`WeaponKind.BAZOOKA` and later `GRENADE_LAUNCHER`): during `cooldown_timer > 0.0` or `is_reloading`, slide `"Warhead"` / tilt launcher down & animate right hand feeding a fresh rocket/shell into the tube!
3. **Tests (`tests/test_runner.gd`):** verify COD crosshair (Bottom/Left/Right gray visible, Top hidden, diagonal ticks open center, normal=gray, headshot=red, kill=white) and verify `"Pump"` & `"Warhead"` animate positions during cycle/reload.

---

### Task 4: Demolisher Class Foundation, Visuals, Icons, NetSync, 5 Skills & FirePatch Hazard (Item 4 — Part A)

**Files:**
- Create: `entities/characters/classes/class_demolisher.gd`
- Create: `entities/skills/demolisher_skills.gd`
- Modify: `core/network/network_manager.gd`
- Modify: `core/network/net_serializer.gd`
- Modify: `entities/weapons/weapon_base.gd`
- Modify: `audio/sound_synthesizer.gd`
- Modify: `entities/characters/hero_mesh_builder.gd`
- Modify: `vfx_shaders/cartoon_assets.gd`
- Modify: `entities/skills/status_effect_container.gd`
- Modify: `entities/skills/skill_catalog.gd`
- Modify: `entities/skills/skill_manager.gd`

**Requirements:**
1. **`NetworkManager` & `NetSerializer`:**
   - `NetworkManager.CLASS_DEMOLISHER = 3`; update `clampi(..., 0, 3)` in all class helpers (`network_manager.gd`).
   - `NetSerializer`: add `BUFF_HASTE = 1 << 12`, `BUFF_SHIELD_DRAIN = 1 << 13`, `BUFF_VEHICLE_BUSTER = 1 << 14`, `BUFF_TNT_ROPE = 1 << 15`. Keep `INPUT_CMD_BYTES = 15`.
2. **`WeaponBase` & `ClassDemolisher` & `SoundSynthesizer`:**
   - `WeaponKind`: add `FLAMETHROWER = 8`, `GRENADE_LAUNCHER = 9`, `STICK_GRENADE = 10`. Add `caber_spent: bool = false`.
   - `ClassDemolisher`: `HP = 110`, `move_speed = 5.4`, loadout `[FLAMETHROWER, GRENADE_LAUNCHER, STICK_GRENADE]`.
   - Stats & variants in `WeaponBase`:
     - `FLAMETHROWER`: `0 = Flamethrower` (`100` mag, `0.1s` interval / `10 ammo/s`, `5 dmg` contact + `5 dmg/0.5s` `3.0s` Afterburn, `11.0m` range); `1 = Fire Starter` (`100` mag, `0.05s` interval / `20 ammo/s`, `5 dmg` contact + `3.0s` Afterburn + ground `FirePatchEntity`, `15.5m` range); `2 = Fire Breath` (`100` mag, `0.5s` interval, consumes `10` ammo/shot, `40 dmg` fireball + `3.0s` Afterburn, `52.0m` range).
     - `GRENADE_LAUNCHER`: `0 = Lança-Granadas` (`6` mag, oblique bouncing grenades w/ `2.0s` fuse after bounce, `60` max AoE); `1 = Trapper` (`6` mag, sticky grenades armed after `0.5s`, right-click detonate, `40` max AoE, destroyable by enemies); `2 = Canhão` (`1` mag, fast low-drop cannonball exploding on any contact, `100` max AoE).
     - `STICK_GRENADE`: `0/1/2 = Granada de Cabo` (melee stick grenade, `60` AoE + `60` self-dmg on 1st hit, then `caber_spent = true` normal club `35 dmg` until respawn).
   - Wire Haste (`fire_rate_mult`, `reload_rate_mult` from `StatusEffectContainer`) into `WeaponBase.step_timers` & `start_reload`.
   - Add procedural SFX clips in `SoundSynthesizer` for `FLAMETHROWER`, `GRENADE_LAUNCHER`, `STICK_GRENADE`.
3. **3D Visuals & 2D Icons (`hero_mesh_builder.gd`, `cartoon_assets.gd`, `status_effects_vfx.gd`):**
   - Demolisher 3D silhouette/rig in `HeroMeshBuilder` & `HeroCharacter._get_visual_style`: heavy blast pads, grenade belt/bandolier, fuel tanks backpack, blast visor helmet; team colors Royal / National (`portrait_royal_3`, `portrait_national_3`).
   - 3D weapon models + `2D` weapon icons (`icon_weapon_8/9/10_0..2`) + `5` Demolisher `40x40` skill icons (`icon_skill_3_0..4`). Name `"CaberHead"` on `STICK_GRENADE` so it hides cleanly when `caber_spent`.
   - Ground `FirePatchEntity` visual & `RiotShieldEntity` visual & spinning `TNT Rope` hand visual.
4. **Status Effects & `DemolisherSkills` (`status_effect_container.gd`, `demolisher_skills.gd`, `skill_catalog.gd`):**
   - In `StatusEffectContainer`:
     - Track `haste_timer` (`fire_rate_mult = 1.45`, `reload_rate_mult = 1.55`, `speed_boost_mult = 1.35`), `damage_to_shield_timer` (3s) + `damage_to_shield_temp: int` (ONLY this temp shield is subtracted/removed when the `3.0s` timer ends — never touches permanent HP!), `vehicle_triple_dmg_timer` (3s, `get_vehicle_damage_mult() -> float` returns `3.0` while `> 0`), and `tnt_rope_active: bool`.
     - Add `notify_damage_dealt_server(raw_damage: int)` called from weapons/projectiles: if `damage_to_shield_timer > 0.0` and `owner_hero != null` and not `owner_hero.is_defeated`, adds `raw_damage` to `owner_hero.shield` and records it in `damage_to_shield_temp` (clamped/removed cleanly when timer hits `0.0`).
   - Implement `DemolisherSkills` (`5` skills) + `RiotShieldEntity` (`150 HP`, Layer 1 or dedicated blocking collider taking bullet/explosive damage cleanly from enemies!) + `FirePatchEntity` (`6.0s` max duration, `20` instant entry dmg + `3.0s` Afterburn reset, ignores `is_in_water` & `fire_immunity_timer > 0.0`, extinguished by `Água` widget!).
   - Register Demolisher skills in `SkillCatalog` and update `HeroCharacter._apply_class_defaults` & `skill_manager` setup for `CLASS_DEMOLISHER`.

---

### Task 5: Demolisher Weapons Gameplay — `FlameWeapon`, Launcher Projectiles, Destroyable Stickies & Stick Grenade Melee (Item 4 — Part B)

**Files:**
- Create: `entities/weapons/flame_weapon.gd`
- Modify: `entities/weapons/projectile_entity.gd`
- Modify: `entities/weapons/projectile_weapon.gd`
- Modify: `entities/weapons/hitscan_weapon.gd`
- Modify: `entities/characters/classes/class_demolisher.gd`
- Modify: `entities/characters/hero_character.gd`
- Modify: `core/main_game.gd`

**Requirements:**
1. **`ProjectileEntity` (`entities/weapons/projectile_entity.gd`):**
   - Add `ProjectileKind`: `FIREBALL`, `BOUNCE_GRENADE`, `CANNON_BALL`, `TRAPPER_STICKY`, `TNT_ROPE_CLUSTER`.
   - `FIREBALL`: `40 dmg` on hero/vehicle direct hit (multiplied `3x` on vehicles if shooter has Vehicle Buster!), applies/resets `3.0s` Afterburn (`5 dmg / 0.5s`) unless target `is_in_water` or `fire_immunity_timer > 0.0`; feeds shooter's Skill 4 shield!
   - `BOUNCE_GRENADE`: `60` max splash damage (`splash_radius = 6.5`, distance falloff), bounces on Layer 1 surfaces and starts a **`2.0s` fuse** on first bounce (`_bounce_fuse_started`), detonating immediately if colliding with an enemy hero or vehicle!
   - `CANNON_BALL`: `100` max splash damage (`splash_radius = 7.5`), high X velocity (`72.0 m/s`), mild gravity (`0.42` low drop), `explode_on_impact = true` on ANY hit (world, prop, hero, vehicle).
   - `TRAPPER_STICKY`: `40` max splash damage (`splash_radius = 6.0`), sticks on contact (`_stuck = true`, zero velocity/gravity while stuck), tracks `_age_sec += delta`, can ONLY be manually detonated when `_age_sec >= 0.5`. Has `sticky_hp: int = 1` + small hit area/registration in `stickies` / Layer 7 or direct raycast check in `HitscanWeapon` & splash damage in `_detonate()` so **any enemy damage destroys the sticky silently without exploding!** Max 6 active stickies per shooter.
   - `TNT_ROPE_CLUSTER` (from Demolisher Skill 3): high AoE explosive (`105` max splash damage, `8.5m` radius).
   - Apply `owner.status_effects.get_vehicle_damage_mult()` (`3x`) when damaging vehicles and `owner.status_effects.notify_damage_dealt_server(dmg)` in `_detonate()` and direct impacts!
2. **`FlameWeapon` (`entities/weapons/flame_weapon.gd`):**
   - Continuous stream for `Flamethrower` (`arch 0`, `0.1s` tick, `1` ammo/tick = `10/s`, `11m` range) & `Fire Starter` (`arch 1`, `0.05s` tick, `1` ammo/tick = `20/s`, `15.5m` range). Each contact tick deals `5` dmg (tripled on vehicles if Vehicle Buster active, feeds Skill 4 shield) + applies/resets `3.0s` Afterburn (`5 dmg / 0.5s`). Ignored completely if target `is_in_water` or `fire_immunity_timer > 0.0`!
   - `Fire Starter` additionally spawns/refreshes `FirePatchEntity` (`6.0s` max life, `20` instant dmg + Afterburn) where flame strikes ground/wall (`normal.y >= 0.3` and above `WATER_LEVEL`).
   - `Fire Breath` (`arch 2`): fires `FIREBALL` every `0.5s` consuming `10` ammo (`52m` max reach), `40 dmg` + `3.0s` Afterburn.
3. **`ProjectileWeapon` (`entities/weapons/projectile_weapon.gd`):**
   - Handle `WeaponKind.GRENADE_LAUNCHER`: fire `BOUNCE_GRENADE` / `CANNON_BALL` / `TRAPPER_STICKY`; for `Trapper`, right-click (`BTN_AIM` rising edge) detonates all stickies owned by `owner_hero` whose `_age_sec >= 0.5`.
4. **`HitscanWeapon` (`entities/weapons/hitscan_weapon.gd`):**
   - Support damaging/destroying `RiotShieldEntity` and enemy `TRAPPER_STICKY` nodes on hitscan raycasts + apply Vehicle Buster `3x` dmg and Skill 4 `notify_damage_dealt_server` on gunfire!
   - For `WeaponKind.STICK_GRENADE`: if `not caber_spent` and melee swing hits any enemy hero/vehicle/prop: trigger AoE explosion (`60` max splash damage on nearby enemies within `5.5m`, `60` self-damage to Demolisher via `apply_damage_server(60, owner_hero.entity_id, true, false, false)`, knockback + `"explosion_vfx"`), set `caber_spent = true`, update `"CaberHead"` visibility (`false`)! When `caber_spent == true`, behave as standard `35`-dmg melee club until `reset_weapons_full()` on respawn.
5. **Skill 3 TNT Rope block & throw (`HeroCharacter`, `MainGame`, `DemolisherSkills`):**
   - While `status_effects.tnt_rope_active == true`, block normal `w.try_consume_fire` / weapon shots in `MainGame._physics_process`, and on Left-Click (`BTN_FIRE`) trigger `DemolisherSkills.throw_tnt_rope(cmd, context)`!

---

### Task 6: UI/Menu Integration (4-Class Select, Skills Guide, Bot AI, Cache Pre-Warm) & Complete Phase 11 Automated Verification Suite

**Files:**
- Modify: `entities/characters/hero_character.gd`
- Modify: `core/main_game.gd`
- Modify: `core/ai/bot_controller.gd`
- Modify: `ui/class_select_menu.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `core/game_cache.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. **`ClassSelectMenu` (`ui/class_select_menu.gd`):**
   - Replace hardcoded `0..2` class count with `0..3` including **`DEMOLISHER`** (card 4 in Armory/Lobby cleanly fitted inside main panel + `get_class_weapon_slots(3)` = `[FLAMETHROWER, GRENADE_LAUNCHER, STICK_GRENADE]` + `"HP 110 • 5.4 m/s"` + Demolisher skill summary + `3` variant buttons per slot matching exact names `Flamethrower / Fire Starter / Fire Breath`, `Lança-Granadas / Trapper / Canhão`, `Granada de Cabo`).
   - Skills Encyclopedia (`Habilidades`): add tab `"Demolisher (5)"` cleanly alongside Soldier/Gunner/Commando/Itens (`"Água"`).
2. **`HUDController`, `MainGame`, `BotController`, `GameCache`:**
   - Update `HUDController` (`portrait_royal_3` / `portrait_national_3`, Demolisher 5 skill slots, `"Água"` widget tooltip/label).
   - Update `MainGame._spawn_14v14_bots` (`% 4`) + client event handlers for `"fire_patch_vfx"`, `"riot_shield"`, `"caber_spent"`.
   - Update `BotController` so Demolisher bots navigate, use flamethrowers at close range (<14m), grenade launchers at medium range (<40m), and trigger Riot Shield / Haste / Vehicle Buster sensibly.
   - Update `GameCache.warm_textures()` & `warm_meshes()` for `WeaponKind 0..10`, `cls 0..3`, icons `0..3`.
3. **Comprehensive Automated Verification (`tests/test_runner.gd`):**
   - Add `await _test_phase11_all_items()` verifying EVERY requirement of Items 1–7 end-to-end:
     - **P11.1:** Poisoned Blade adds `0` instant bonus on melee hit, applies pure `0.5s` DoT ticks over `6.0s`, Antidote cleanses + resets tick accum.
     - **P11.2:** Ground vehicles stall in water, do NOT explode, vanish silently only when empty (`get_occupant_count() == 0`), respawn cleanly; Boat has exact 3 seats, Driver cannot shoot, Seat 1 shoots from bow turret barrel, Seat 2 stands behind pilot; APC Driver cannot shoot solo, Seat 1 shoots roof MG, Seat 2 sits facing backwards (`PI`) and shoots/uses items.
     - **P11.3:** Freefall stays false `< 1.0s` airborne & enables at `>= 1.0s`; crouching articulates thighs (`+X`) + knees (`-X`) without burying torso or sinking boots; stair/hill jump deals `0` fall damage while steep >6m fall deals damage.
     - **P11.4:** Demolisher `HP=110`, `speed=5.4`, all 3 Flamethrowers (continuous `10/s`, Fireball `40 dmg`, `Fire Starter 20/s` + `6.0s` ground fire `20` instant + Afterburn refresh, zero fire dmg in water or within `2.0s` of `Água` widget), all 3 Launchers (`2.0s` bounce fuse, fast 1-shot `100` dmg Cannon, destroyable/0.5s-armed right-click `Trapper` stickies), 1-shot `60` AoE + `60` self `Stick Grenade` resetting on respawn, and all 5 Demolisher skills (`150 HP` Riot Shield, Haste speed/fire/reload, no-timeout TNT Rope blocking gun until Left-Click throw, 3s Temp Shield disappearing at `3.0s`, `3x` Vehicle Damage).
     - **P11.5:** COD crosshair (Bottom/Left/Right gray, Top hidden, diagonal hitmarker ticks: gray normal, red headshot, white kill).
     - **P11.6:** Shotgun `"Pump"` and Bazooka/Cannon `"Warhead"` animate during post-shot cycle/reload.
     - **P11.7:** Gunner `Hero Shield` + `Frenzy Fire` 4th-hit lifesteal heals `hp` strictly with `0` change to `shield`.
   - Confirm map budgets (`MeshInstance3D <= 900`, unique meshes `<= 350`, unique materials `<= 200`) and `0 failed` across the entire suite!
