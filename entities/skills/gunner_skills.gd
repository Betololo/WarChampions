class_name GunnerSkills
extends SkillManager

## Gunner's 5 Heroic Skills:
## 0: Hero Shield, 1: Leg It, 2: Explosive Keg, 3: Frenzy Fire, 4: I Eat Grenades

func _ready() -> void:
	super._ready()
	skill_names = ["Hero Shield", "Leg It", "Explosive Keg", "Frenzy Fire", "I Eat Grenades"]
	skill_max_cooldowns = [16.0, 15.0, 18.0, 17.0, 20.0]


func _execute_class_skill(slot_idx: int, rank: int, cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null:
		return false
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})

	match slot_idx:
		0: # Hero Shield: Blue energy absorption shield
			if owner_hero.status_effects != null:
				owner_hero.status_effects.apply_shield(45 + rank * 22, 6.0 + float(rank), true)
				return true
			return false

		1: # Leg It: Movement speed surge for Gunner and nearby allies
			var mult: float = 1.38 + float(rank) * 0.06
			var dur: float = 4.5 + float(rank) * 0.7
			var radius: float = 11.0
			var affected_ids: Array[int] = [owner_hero.entity_id]
			if owner_hero.status_effects != null:
				owner_hero.status_effects.apply_speed_boost(mult, dur, false)
			for id_key in heroes_by_id.keys():
				var ally: HeroCharacter = heroes_by_id[id_key]
				if ally != null and ally != owner_hero and not ally.is_defeated and ally.team == owner_hero.team:
					if ally.global_position.distance_to(owner_hero.global_position) <= radius and ally.status_effects != null:
						ally.status_effects.apply_speed_boost(mult, dur, false)
						affected_ids.append(ally.entity_id)
			_record_aoe_effect(radius, affected_ids, owner_hero.global_position)
			return true

		2: # Explosive Keg: Heavy rolling barrel with splash & concussion slow
			var forward: Vector3 = -Basis(Vector3.UP, cmd.aim_yaw).z.normalized()
			ProjectileEntity.spawn_server_projectile(
				ProjectileEntity.ProjectileKind.EXPLOSIVE_KEG,
				owner_hero.entity_id,
				owner_hero.team,
				owner_hero.global_position + Vector3(0.0, 1.4, 0.0) + forward * 1.1,
				(forward + Vector3(0.0, 0.35, 0.0)).normalized() * (14.0 + float(rank) * 1.2),
				context,
				45.0 + float(rank) * 10.0,
				owner_hero.get_parent()
			)
			return true

		3: # Frenzy Fire: Tighter MG accuracy + heal every 4th accurate shot
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_frenzy_fire(6 + rank * 2, 6.0 + float(rank))
				return true
			return false

		4: # I Eat Grenades: Absorb nearby explosions into HP healing
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_eat_grenades(4.0 + float(rank) * 0.8)
				return true
			return false

	return false
