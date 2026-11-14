class_name CommandoSkills
extends SkillManager

## Commando's 5 Heroic Skills:
## 0: Stealth, 1: Piercing Shot, 2: Poisoned Blade, 3: Troop Trap, 4: Elixir

func _ready() -> void:
	super._ready()
	skill_names = ["Stealth", "Piercing Shot", "Poisoned Blade", "Troop Trap", "Elixir"]
	skill_max_cooldowns = [15.0, 14.0, 14.0, 16.0, 18.0]


class TroopTrapEntity extends Node3D:
	var owner_id: int = -1
	var owner_team: int = 0
	var damage: int = 65
	var trigger_radius: float = 2.4
	var arm_timer: float = 1.0
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


func _execute_class_skill(slot_idx: int, rank: int, _cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null:
		return false

	match slot_idx:
		0: # Stealth: Detection radius drops from 12m (rank 1) down to 4m (rank 5)
			var detect_r: float = maxf(4.0, 12.0 - float(rank - 1) * 2.0)
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_stealth(detect_r, 8.0 + float(rank) * 2.5)
				return true
			return false

		1: # Piercing Shot: Boosts Sniper Rifle damage significantly
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_piercing_shot(1.35 + float(rank) * 0.15, 5.0 + float(rank))
				return true
			return false

		2: # Poisoned Blade: Coats Knife with intense green DoT
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_poisoned_blade(10.0 + float(rank) * 3.0, 6.0 + float(rank))
				return true
			return false

		3: # Troop Trap: Plants mechanical proximity landmine
			var trap := TroopTrapEntity.new()
			trap.owner_id = owner_hero.entity_id
			trap.owner_team = owner_hero.team
			trap.damage = 55 + rank * 12
			trap._context = context
			trap.position = owner_hero.global_position + Vector3(0.0, 0.06, 0.0)
			var projectiles_root: Node = context.get("projectiles_root", owner_hero.get_parent())
			if projectiles_root != null:
				projectiles_root.add_child(trap)
			return true

		4: # Elixir: Burst speed + small absorption shield
			if owner_hero.status_effects != null:
				owner_hero.status_effects.apply_speed_boost(1.45 + float(rank) * 0.06, 4.5 + float(rank) * 0.6)
				owner_hero.status_effects.apply_shield(20 + rank * 8, 4.5 + float(rank) * 0.6)
				return true
			return false

	return false
