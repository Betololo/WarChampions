# Phase 8: Procedural Icons for All 16 Skills, Class Skills Guide Menu, AoE Area Indicators, Overhead Active Buff Icons & Plane Throttle/Crash Physics

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every heroic skill a distinct, recognizable procedural icon wired across HUD and menus; add a complete Class Skills Guide screen (with cooldown, duration, damage, heal, and radius stats); render unmistakable 3D ground/target AoE area indicators when team/area skills trigger; float cached billboard icons above characters' heads for every active timed skill buff; and replace instantaneous plane flight with genuine runway acceleration plus destructive ground/wall crash explosions (piloted or ejected).

## Architecture & Design Decisions

1. **Skill Icons (`CartoonAssets` + `HUDController`)**:
   - `_sprite_skill(key_tail)` parses `"<class_id>_<slot_idx>"` (`0_0`..`2_5`) to generate crisp `40x40` outlined Cartoon icons unique to all **16 skills** (preserving `"0"`..`"5"` fallback mapped to class `0`).
   - `HUDController._refresh_hotbar_icons()` updates `_skill_slot_icons` dynamically using `"icon_skill_%d_%d" % [_local_hero.class_id, i]` whenever the hero's class changes, fixing the bug where every class rendered generic circles.
2. **Unified Skill Catalog (`SkillCatalog`) & Skills Guide Screen (`ClassSelectMenu`)**:
   - A lightweight static `SkillCatalog` class (`entities/skills/skill_catalog.gd`) provides canonical Rank-5 specs (Name, Category, Cooldown, Duration, Area/Radius, Damage/Heal, Icon key, Description) for all 16 class skills and 4 widgets — shared cleanly without duplicating metadata inside UI builders.
   - `ClassSelectMenu` adds `"Habilidades"` screen reachable from both Hub and Armory with class filter tabs (`Soldier`, `Gunner`, `Commando`, `Widgets`) sized for `980x620`.
3. **AoE Area Visuals (`SkillManager` + `StatusEffectsVFX` + `MainGame`)**:
   - `SkillManager` stores `_last_aoe_radius: float` and `_last_aoe_targets: Array[Vector3]` populated by `_execute_class_skill` (Combat Medicine `12m`, Blasting Strike `13m`, Sixth Sense `18m`/`85m`, Leg It `11m`) and embeds them in the `"skill_vfx"` event payload without breaking method signatures.
   - `StatusEffectsVFX.spawn_skill_vfx` renders an expanding ground ring + translucent pulse disc at exact `aoe_radius` plus vertical highlight pulses on each affected target position using shared cached meshes and `SHADOW_CASTING_SETTING_OFF`.
4. **Replicated Overhead Active Buff Icons (`NetSerializer` + `StatusEffectContainer` + `HeroCharacter` + `StatusEffectsVFX`)**:
   - Dedicated `active_buffs: int` (`u16`) packed alongside hero snapshot entries (`2` bytes/hero in `WorldSnapshot`, preserving `INPUT_CMD_BYTES = 15`) tracks `BUFF_SHIELD`, `BUFF_SPEED`, `BUFF_BURNING_BULLETS`, `BUFF_POISONED_BLADE`, `BUFF_FRENZY_FIRE`, `BUFF_PIERCING_SHOT`, `BUFF_EAT_GRENADES`, `BUFF_SIXTH_SENSE`, `BUFF_COMBAT_MED_HOT`, `BUFF_FIREPROOF`, `BUFF_BANDAGE`.
   - `HeroCharacter` maintains up to `5` pooled `Sprite3D` billboard nodes above the head (`y = 2.48m`) updated only inside `StatusEffectsVFX.update_hero_client_visuals` when the composite dirty key (`active_buffs`, `class_id`, `is_stealthed`, `is_defeated`, enclosure) changes — zero per-frame node creation or texture churn.
5. **Plane Runway Acceleration & Crash Explosions (`VehiclePlane`)**:
   - Tracks explicit `_airspeed`, `_was_airborne`, `_last_pilot_id`, `_last_pilot_team`, and `_unmanned_fall_time`.
   - Neutral throttle idles at `0` on the runway; `W` accelerates gradually along runway wheels (`GROUND_ACCEL = 22.0`) and unlocks lift + climb only once `_airspeed >= TAKEOFF_SPEED (21.0 m/s)`; airborne `W/S` modulate smoothly between stall speed (`16.0`) and `MAX_FLIGHT_SPEED (52.0)`.
   - Unpiloted planes retain forward momentum and nose down under gravity rather than braking mid-air. Hitting walls (`_check_crash_impact` forward raycast / abrupt impact slowdown) or crashing nose-down/unmanned into terrain/water triggers `_detonate_plane_crash` (`120` center damage -> `45` edge over `12.0m` radius + knockback + kill credit to `_last_pilot_id` + `explosion_vfx` + `_on_destroyed`).

---

### Task 1: All 16 Skill Procedural Icons, HUD Hotbar Sync & Class Skills Guide Menu

**Files:**
- Create: `entities/skills/skill_catalog.gd`
- Modify: `vfx_shaders/cartoon_assets.gd` (`_sprite_skill` unique 16 icons for `"0_0"`..`"2_5"`)
- Modify: `ui/hud_controller.gd` (`_refresh_hotbar_icons()` updates `_skill_slot_icons` with `"icon_skill_%d_%d"`)
- Modify: `ui/class_select_menu.gd` (add `"skills"` encyclopedia screen with class tabs + full Rank-5 stats cards, reachable from Hub & Armory)
- Test: `tests/test_runner.gd` (unique textures for all 16 skills, HUD updates icons on class change, Skills Guide UI renders all 16 skills + 4 widgets)

### Task 2: AoE Area Ring/Target Visuals & Overhead Active Skill Buff Icons

**Files:**
- Modify: `core/network/net_serializer.gd` (`BUFF_*` constants + `u16 buffs` in hero snapshots)
- Modify: `entities/skills/status_effect_container.gd` (sync `owner_hero.active_buffs` & clear cleanly)
- Modify: `entities/skills/skill_manager.gd`, `entities/skills/soldier_skills.gd`, `entities/skills/gunner_skills.gd` (`_last_aoe_radius`, `_last_aoe_targets` broadcast in `"skill_vfx"`)
- Modify: `entities/characters/hero_character.gd` (`active_buffs`, `buffs` in snapshot dict, pooled overhead `Sprite3D` row helpers)
- Modify: `vfx_shaders/status_effects_vfx.gd` (`aoe_radius` + `affected_positions` ground ring & target pulse visuals; dirty-gated overhead buff `Sprite3D` icon updates)
- Modify: `core/main_game.gd` (forward `aoe_radius` and `affected_pos` from `"skill_vfx"` event)
- Test: `tests/test_runner.gd` (snapshot `buffs` roundtrip, `StatusEffectContainer` buff mask sync, overhead `Sprite3D` icon visibility/count across frames, AoE ring/disc spawn scaling with radius)

### Task 3: Plane Runway Acceleration Curve & Ground/Wall Crash Explosion Damage

**Files:**
- Modify: `entities/vehicles/vehicle_plane.gd` (`_airspeed`, runway acceleration curve, takeoff gating at `TAKEOFF_SPEED`, unmanned ballistic descent, wall/terrain impact detection & `_detonate_plane_crash` splash damage/knockback/kill credit, `_respawn_vehicle` reset)
- Test: `tests/test_runner.gd` (no instant takeoff at idle or first ticks, progressive acceleration & liftoff past `TAKEOFF_SPEED`, Space climb preserved, piloted wall crash explosion, ejected unmanned plane crash deals AoE explosion damage to nearby enemy bots and respawns plane cleanly)
