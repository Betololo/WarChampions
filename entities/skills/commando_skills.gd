class_name CommandoSkills
extends SkillManager

## Commando's 6 Heroic Skills:
## 0: Stealth, 1: Piercing Shot, 2: Poisoned Blade, 3: Troop Trap, 4: Elixir, 5: Mark Target

var _active_traps: Array[TroopTrapEntity] = []


func _ready() -> void:
	super._ready()
	skill_names = ["Stealth", "Piercing Shot", "Poisoned Blade", "Troop Trap", "Elixir", "Mark Target"]
	skill_ranks = [5, 5, 5, 5, 5, 5]
	skill_cooldowns = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	skill_max_cooldowns = [15.0, 14.0, 14.0, 16.0, 18.0, 20.0]


func _defers_cooldown_until_exit(slot_idx: int) -> bool:
	return slot_idx == 0


class TroopTrapEntity extends Node3D:
	var owner_id: int = -1
	var owner_team: int = 0
	var damage: int = 65
	var trigger_radius: float = 2.4
	var arm_timer: float = 1.0
	var lifetime_remaining: float = 60.0
	var _context: Dictionary = {}
	var _detonated: bool = false

	func _ready() -> void:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.42
		cyl.height = 0.12
		mi.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.24, 0.28, 0.22)
		mi.material_override = mat
		add_child(mi)

	func _physics_process(delta: float) -> void:
		if _detonated:
			return
		lifetime_remaining -= delta
		if lifetime_remaining <= 0.0:
			queue_free()
			return
		if arm_timer > 0.0:
			arm_timer -= delta
			return
		var heroes_by_id: Dictionary = _context.get("heroes_by_id", {})
		for id_key in heroes_by_id.keys():
			var h: HeroCharacter = heroes_by_id[id_key]
			if h != null and not h.is_defeated and h.team != owner_team:
				if h.global_position.distance_to(global_position) <= trigger_radius:
					_explode(heroes_by_id)
					return
		if is_inside_tree():
			for v in get_tree().get_nodes_in_group("vehicles"):
				if v is Node3D and v.get("team") != owner_team:
					if (v as Node3D).global_position.distance_to(global_position) <= trigger_radius + 1.5:
						if v.has_method("apply_damage_server"):
							v.apply_damage_server(damage * 2, owner_id, Vector3.UP, global_position, true)
						_explode(heroes_by_id)
						return

	func _explode(heroes_by_id: Dictionary) -> void:
		_detonated = true
		for id_key in heroes_by_id.keys():
			var h: HeroCharacter = heroes_by_id[id_key]
			if h != null and not h.is_defeated and h.team != owner_team:
				var d: float = h.global_position.distance_to(global_position)
				if d <= 5.5:
					h.apply_damage_server(damage, owner_id, true)
					h.apply_knockback((h.global_position - global_position + Vector3(0.0, 0.8, 0.0)).normalized() * 12.0)
					NetworkManager.broadcast_game_event("hit_vfx", {
						"pos": h.global_position + Vector3(0.0, 1.85, 0.0),
						"kind": "spark",
						"attacker_id": owner_id,
						"victim_id": h.entity_id,
						"damage": damage,
						"headshot": true,
					})
		NetworkManager.broadcast_game_event("explosion_vfx", {"pos": global_position, "radius": 5.5, "kind": 99})
		queue_free()


func _execute_class_skill(slot_idx: int, rank: int, cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null:
		return false

	match slot_idx:
		0: # Stealth: Infinite duration until attack, >15 dmg, or Mark Target (cooldown starts on exit)
			if owner_hero.is_stealthed:
				return false
			if owner_hero.status_effects != null and owner_hero.status_effects.is_marked():
				return false
			var detect_r: float = maxf(4.0, 12.0 - float(rank - 1) * 2.0)
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_stealth(detect_r, -1.0)
				return owner_hero.is_stealthed
			return false

		1: # Piercing Shot: Sniper Rifle pierces multiple aligned enemies + boosted damage
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_piercing_shot(1.35 + float(rank) * 0.15, 5.0 + float(rank))
				return true
			return false

		2: # Poisoned Blade: Coats Knife with intense green DoT (12 dmg/s * 6s = 72)
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_poisoned_blade(9.0 + float(rank) * 3.0, 6.0 + float(rank))
				return true
			return false

		3: # Troop Trap: Max 2 active mines per Commando (60s lifetime)
			var valid_traps: Array[TroopTrapEntity] = []
			for existing in _active_traps:
				if is_instance_valid(existing) and not existing._detonated and not existing.is_queued_for_deletion():
					valid_traps.append(existing)
			_active_traps = valid_traps
			while _active_traps.size() >= 2:
				var oldest: TroopTrapEntity = _active_traps.pop_front()
				if is_instance_valid(oldest):
					oldest.queue_free()

			var trap := TroopTrapEntity.new()
			trap.owner_id = owner_hero.entity_id
			trap.owner_team = owner_hero.team
			trap.damage = 55 + rank * 12
			trap.lifetime_remaining = 60.0
			trap._context = context
			trap.position = owner_hero.global_position + Vector3(0.0, 0.06, 0.0)
			var projectiles_root: Node = context.get("projectiles_root", owner_hero.get_parent())
			if projectiles_root != null:
				projectiles_root.add_child(trap)
			_active_traps.append(trap)
			return true

		4: # Elixir: Burst speed + small absorption shield
			if owner_hero.status_effects != null:
				var elx_dur: float = 4.5 + float(rank) * 0.6
				owner_hero.status_effects.apply_speed_boost(1.45 + float(rank) * 0.06, elx_dur, true)
				owner_hero.status_effects.apply_shield(20 + rank * 8, elx_dur, false)
				return true
			return false

		5: # Mark Target: Instantly marks 1 enemy or vehicle under crosshair in LOS at any distance for 12s & breaks Stealth
			if owner_hero.status_effects != null:
				return owner_hero.status_effects.try_mark_crosshair_target(context, cmd.aim_yaw, cmd.aim_pitch, 12.0)
			return false

	return false
