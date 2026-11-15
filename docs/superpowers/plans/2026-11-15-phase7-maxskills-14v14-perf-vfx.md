# Phase 7: Max-Rank Skills (Zero Leveling), 14v14, Persistent Hotkeys, FPS Optimization & Thematic Skill VFX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove skill leveling/upgrade locks so all 16 heroic skills launch at Rank 5 (max level), tune battles from 20v20 to 14v14, make hotkey customization prominent and persistent in the menu, fix the Phase 6 FPS lag regression, and replace generic colored rings with thematic 3D skill/widget VFX and animations.

**Architecture:** All server gameplay progression defaults (`SkillManager`, `CommandoSkills`, `NetworkManager`, `MapSeasideFrontline`, `MainGame`) are locked cleanly on the server without UI click gates; rendering/UI overhead is eliminated via dirty-state caching (`StatusEffectsVFX`, `HeroCharacter`, `VehicleBase`, `HUDController`) and pooled/shared primitives (`GameCache`, `StatusEffectsVFX`); and every skill/widget spawns recognizable multi-part thematic 3D meshes + distinct procedural hero poses.

**Tech Stack:** Godot Engine 4.7.2 (statically typed GDScript, Forward+ Vulkan, ENetMultiplayerPeer).

## Global Constraints
- All class skills (Soldier 5, Gunner 5, Commando 6) initialize unlocked at **Rank 5 (`MAX_SKILL_RANK = 5`)** with `hero_points = 0`; zero `+` upgrade buttons or rank-0 locks remain.
- Match capacity is **`14v14`** (`MAX_PLAYERS = 28`, `MAX_PLAYERS_PER_TEAM = 14`; Offline Bots spawns `13` AllyBots + `14` EnemyBots = `28`; Online Host/Dedicated starts with **`0` bots**).
- Hotkey customization must be directly reachable from both the Hub and Armory screens, persist via `ConfigFile`, never steal ESC while canceling listen mode, and update HUD labels immediately.
- Zero per-frame `material_overlay` / `set_shader_parameter` writes or recursive tree walks when hero/vehicle visual state is unchanged; zero per-frame `StyleBoxFlat.new()` or `Label.new()` churn in `HUDController`; `GameCache` warms all skill/widget icons + `xray_silhouette.gdshader` + shared VFX meshes during loading.
- Every skill (`0..4`/`0..5`) and widget (`100..103`) must spawn thematic, recognizable 3D VFX (e.g., rising crosses for heals, foot dust/speed streaks for speed boosts, shock cones, laser beams, domes) + distinct procedural poses.

## Review Focus
- `SkillManager` Rank 5 initialization must not break `CommandoSkills` (6 slots `[5,5,5,5,5,5]`), `SoldierSkills` (`[5,5,5,5,5]`), `GunnerSkills` (`[5,5,5,5,5]`), or `HUDController` hotbar display.
- `StatusEffectsVFX` dirty-state cache must still immediately update when stealth, burning, poisoned, shielded, vehicle enclosure, or X-Ray mark/sixth-sense changes (including toggling *back* to normal!).
- `HUDController` pooled markers and cached seat `StyleBoxFlat` styles must handle dynamic team swaps, seat switches, and hiding overlays cleanly when exiting vehicles or defeated.
- `InputCmd` `ConfigFile` load/save helpers must accept a configurable path (default `"user://hotkeys.cfg"`) so automated tests do not pollute user preferences.
- Thematic 3D VFX nodes must work safely both in headless (`0` nodes without crashing) and Forward+ Vulkan (`parent.add_child(...)`, shared cached meshes, auto `queue_free()` via `Tween`).

---

### Task 1: All Skills Rank 5 Maxed + 14v14 Capacity + HUD Pooling/Reuse Optimization

**Files:**
- Modify: `entities/skills/skill_manager.gd:31-78`
- Modify: `entities/skills/commando_skills.gd:10-16`
- Modify: `core/network/network_manager.gd:26-79`
- Modify: `maps/map_seaside_frontline.gd:4,870-885`
- Modify: `core/main_game.gd:114-120,221-225,389-466,742-748`
- Modify: `ui/hud_controller.gd` (`_upgrade_buttons`, `_hero_pts_lbl`, `_marker_pool`, cached seat `StyleBoxFlat`s, dirty label updates)
- Test: `tests/test_runner.gd` (Rank 5 maxed, no `+` locks, `14v14` capacity/pads/bots, HUD pooled markers & cached seat styles)

**Interfaces:**
- Produces: `NetworkManager.MAX_PLAYERS == 28`, `NetworkManager.MAX_PLAYERS_PER_TEAM == 14`, `SkillManager.skill_ranks` all `5`, `MainGame._spawn_14v14_bots(human_team)`, `HUDController` pooled markers + cached seat styles.

- [ ] **Step 1:** Set `SkillManager` (`hero_points = 0`, `skill_ranks = [5, 5, 5, 5, 5]`, `upgrade_skill` returns `false`, `level = 5`) and `CommandoSkills` (`skill_ranks = [5, 5, 5, 5, 5, 5]`).
- [ ] **Step 2:** Set `NetworkManager` (`MAX_PLAYERS = 28`, `MAX_PLAYERS_PER_TEAM = 14`), `MapSeasideFrontline` (14 Royal + 14 National spawn pads), and `MainGame` (`_spawn_14v14_bots`, `14 vs 14` strings, cached `_cached_combat_ctx` rebuilt only when entities/vehicles change).
- [ ] **Step 3:** Update `HUDController`: remove `+` upgrade button visibility/hero-pts clutter, show `MAX` / `R5` cleanly, pool `_sixth_sense_layer` `Label`s, cache seat diagram `StyleBoxFlat` templates + seat state key, and dirty-check frequent HUD label text assignments.
- [ ] **Step 4:** Verify compilation & existing tests (updating stale 20v20 / Rank 1 expectations as needed), commit cleanly.

---

### Task 2: Prominent & Persistent Hotkey Customization Menu (Hub + Armory + Settings)

**Files:**
- Modify: `core/network/input_cmd.gd` (`save_hotkeys_to_config(path: String = "user://hotkeys.cfg")`, `load_hotkeys_from_config(path: String = "user://hotkeys.cfg")`)
- Modify: `ui/class_select_menu.gd` (14v14 copy, collapsed `_mp_drawer` by default on Hub so "Configurações & Hotkeys" is immediately visible, "Atalhos (Hotkeys)" button in Armory, return target tracking `"hub"`/`"armory"`, hotkey conflict guard/swap, `ConfigFile` persistence, ESC listen cancel)
- Test: `tests/test_runner.gd` (14v14 labels, Armory settings button navigation, `InputCmd` config save/load roundtrip on temp path)

**Interfaces:**
- Consumes: `NetworkManager`, `InputCmd`, `HUDController.refresh_hotkey_labels()`
- Produces: `InputCmd.save_hotkeys_to_config(path: String = "user://hotkeys.cfg") -> int`, `InputCmd.load_hotkeys_from_config(path: String = "user://hotkeys.cfg") -> bool`

- [ ] **Step 1:** Add `ConfigFile` save/load to `InputCmd` and load on menu init (guarding headless/unit-test isolation).
- [ ] **Step 2:** Refine `ClassSelectMenu` Hub/Armory/Settings layout & 14v14 copy so Hotkeys customization is front-and-center from Hub, Armory, and Pause (`ESC`), fits `980x620` cleanly, and persists on bind/reset.
- [ ] **Step 3:** Verify UI/config roundtrip & commit.

---

### Task 3: Frame-Rate Optimization (`GameCache`, `BotController`, `StatusEffectsVFX` Dirty Cache) & Thematic 3D VFX/Poses for All 16 Skills & 4 Widgets

**Files:**
- Modify: `core/game_cache.gd` (add `xray_silhouette.gdshader`, `icon_skill_2_5`, `icon_widget_fireproof`, `icon_widget_antidote`, remove stale `icon_widget_tonic`, warm `StatusEffectsVFX.warm_shared_meshes()`)
- Modify: `core/ai/bot_controller.gd` (distance-squared prefilter + closest-first sorted LOS + 6-tick full-scan stagger)
- Modify: `entities/characters/hero_character.gd` (`_last_vfx_key` cache field + new distinct procedural poses e.g. `sprint_boost`, `chomp_absorb` covering every skill/widget rhythmically)
- Modify: `entities/vehicles/vehicle_base.gd` (`_cached_visual_meshes`, `_last_xray_state`)
- Modify: `vfx_shaders/status_effects_vfx.gd` (dirty-state gating on `update_hero_client_visuals` & `update_vehicle_client_visuals`, shared cached primitive meshes, and thematic multi-part 3D VFX builders for all 16 skills + 4 widgets: rising heal `+` crosses, speed wind streaks & foot dust puffs, shield dome, blast shock cone, radar sweep arcs, flame embers, piercing beam, venom drips, trap prongs, laser target diamond, absorb chevrons)
- Test: `tests/test_runner.gd` (full Phase 1–7 suite covering GameCache new keys + XRay shader warm, dirty-state VFX cache invalidation on status/cloak/mark change, thematic multi-child 3D VFX node types under Forward+ Vulkan, zero script errors)

- [ ] **Step 1:** Optimize `GameCache` & `BotController` (`dist_sq` sorted LOS + full texture/shader prewarm).
- [ ] **Step 2:** Implement dirty-state caching on `HeroCharacter`, `VehicleBase`, and `StatusEffectsVFX` + shared mesh cache.
- [ ] **Step 3:** Implement thematic 3D VFX & matching poses for all 16 skills + 4 widgets in `StatusEffectsVFX` & `HeroCharacter`.
- [ ] **Step 4:** Add comprehensive Phase 7 assertions to `tests/test_runner.gd`, verify BOTH `--headless` AND Forward+ Vulkan `--verbose` (`0 failed`, `0 SCRIPT ERROR`), and commit.
