# Phase 12: Field Engineer Class, Polished 3D Menus, Minimap, Alt-Drag Hotbar & Combat Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to execute all 5 tasks sequentially without pausing.

**Goal:** Resolve all 6 vehicle/flamethrower/grenade/crosshair bugs, rework Demolisher Skills 0 & 3, add `Shift` hotkey + `Alt` drag-and-drop hotbar + live tactical Minimap, overhaul menus with symmetrical flags + 360° 3D character preview + Arsenal cards, and implement the 5th playable class (**Field Engineer**) with Dual Guns, Shotguns, Welding Torch, Trench, Shielded Mounted MG, Vehicle 2x Armor, Minimap Mortar, and 1.5s Invulnerability.

**Architecture:** Sequential SDD execution starting from green Phase 11 (`25234ce`). `NetSerializer` packs 3-bit `class_id` (`0..7`) in `WorldSnapshot` `meta` bit `6` (`0` extra bytes) and upgrades `active_buffs` to `u32` (`1028B < 1200B` for 24-hero MTU test, `INPUT_CMD_BYTES` strictly `15`).

**Tech Stack:** Godot `v4.7.2-stable`, GDScript strict static typing, procedural 3D meshes (`HeroMeshBuilder`, `VehicleMeshBuilder`, `BuildingMeshBuilder`), headless `tests/test_runner.tscn`.

## Global Constraints
- Strict GDScript static typing on all variables, parameters, and return types.
- `INPUT_CMD_BYTES` must stay `15` bytes (`test_runner.gd`), 24-hero `WorldSnapshot` `< 1200` bytes.
- Map budgets: `MeshInstance3D <= 900`, unique meshes `<= 350`, unique materials `<= 200`.
- Total static map vehicles `<= 32` (`VehicleShieldedMG` deployables are dynamically spawned/tracked).
- Full test suite must pass with `0 failed` after every task.

---

### Task 1: Bugfixes Core — Vehicle Cooldowns/Widgets, Flamethrower/FireStarter Tuning & Point-Blank Fix, Grenade Vehicle Contact + 1s Fuse, High-Contrast Crosshair (Items 1, 2, 4, 5, 6)
See `.superpowers/sdd/2026-11-18-phase12-engineer-menus-minimap-polish/task-1-brief.md`.

### Task 2: Demolisher Skill Reworks — Carried Riot Shield + Weapon 3 Combo & 5-Vest Armor Kit Pickup (Item 3)
See `.superpowers/sdd/2026-11-18-phase12-engineer-menus-minimap-polish/task-2-brief.md`.

### Task 3: `Shift` Hotkey, `Alt` Cursor Drag-and-Drop Hotbar & Live Tactical Minimap (Items 8 & 9)
See `.superpowers/sdd/2026-11-18-phase12-engineer-menus-minimap-polish/task-3-brief.md`.

### Task 4: Field Engineer Class Foundation, Dual Weapons, Welding Torch & 5 Skills + NetSync (Item 10)
See `.superpowers/sdd/2026-11-18-phase12-engineer-menus-minimap-polish/task-4-brief.md`.

### Task 5: 3D Rotating Preview Menus w/ Symmetrical Flags & Arsenal Cards, 5-Class Bot/HUD/Cache Integration & Full Phase 12 Verification Suite (Items 7 & 10 Final)
See `.superpowers/sdd/2026-11-18-phase12-engineer-menus-minimap-polish/task-5-brief.md`.
