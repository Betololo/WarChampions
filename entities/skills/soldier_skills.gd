class_name SoldierSkills
extends SkillManager

## Soldier's 5 Heroic Skills:
## 0: Combat Medicine, 1: Burning Bullets, 2: Grenade Spam, 3: Blasting Strike, 4: Sixth Sense

func _ready() -> void:
	super._ready()
	skill_names = ["Combat Medicine", "Burning Bullets", "Grenade Spam", "Blasting Strike", "Sixth Sense"]
	skill_max_cooldowns = [13.0, 16.0, 18.0, 14.0, 20.0]


func _execute_class_skill(slot_idx: int, rank: int, cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null:
		return false
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var projectiles_root: Node = context.get("projectiles_root", owner_hero.get_parent())

	match slot_idx:
		0: # Combat Medicine: AoE instant heal to self + nearby allies
			var heal_amt: int = 26 + rank * 10
			var radius: float = 9.0 + float(rank) * 1.0
			owner_hero.heal_server(heal_amt)
			for id_key in heroes_by_id.keys():
				var ally: HeroCharacter = heroes_by_id[id_key]
				if ally != null and ally != owner_hero and not ally.is_defeated and ally.team == owner_hero.team:
					if ally.global_position.distance_to(owner_hero.global_position) <= radius:
						ally.heal_server(heal_amt)
			return true

		1: # Burning Bullets: Incendiary DoT for SMG / Pistol
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_burning_bullets(6.0 + float(rank) * 2.0, 5.0 + float(rank) * 0.8)
				return true
			return false

		2: # Grenade Spam: Throws 2..5 frag grenades in a frontal arc
			var count: int = clampi(1 + rank, 2, 5)
			var base_basis := Basis(Vector3.UP, cmd.aim_yaw)
			var forward: Vector3 = -base_basis.z.normalized()
			var right: Vector3 = base_basis.x.normalized()
			for i in range(count):
				var spread_t: float = 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5) * 0.65
				var throw_dir: Vector3 = (forward + right * spread_t + Vector3(0.0, 0.48, 0.0)).normalized()
				var gren := ProjectileEntity.new()
				gren.setup(
					ProjectileEntity.ProjectileKind.FRAG_GRENADE,
					owner_hero.entity_id,
					owner_hero.team,
					owner_hero.global_position + Vector3(0.0, 1.5, 0.0) + forward * 0.8,
					throw_dir * (18.0 + float(i) * 0.8),
					context
				)
				if projectiles_root != null:
					projectiles_root.add_child(gren)
			return true

		3: # Blasting Strike: Shockwave with massive knockback on enemies & light vehicles
			var blast_radius: float = 8.0 + float(rank) * 1.0
			var blast_dmg: int = 10 + rank * 4
			var kb_power: float = 15.0 + float(rank) * 3.0
			for id_key in heroes_by_id.keys():
				var enemy: HeroCharacter = heroes_by_id[id_key]
				if enemy != null and not enemy.is_defeated and enemy.team != owner_hero.team:
					var diff: Vector3 = enemy.global_position - owner_hero.global_position
					if diff.length() <= blast_radius:
						enemy.apply_damage_server(blast_dmg, owner_hero.entity_id, false)
						var dir: Vector3 = (diff.normalized() + Vector3(0.0, 0.65, 0.0)).normalized()
						enemy.apply_knockback(dir * kb_power)
						NetworkManager.broadcast_game_event("hit_vfx", {
							"pos": enemy.global_position + Vector3(0.0, 1.75, 0.0),
							"kind": "spark",
							"attacker_id": owner_hero.entity_id,
							"victim_id": enemy.entity_id,
							"damage": blast_dmg,
						})
			if owner_hero.is_inside_tree():
				for v in owner_hero.get_tree().get_nodes_in_group("vehicles"):
					if v is RigidBody3D and (v as Node3D).global_position.distance_to(owner_hero.global_position) <= blast_radius + 2.0:
						var v_dir: Vector3 = ((v as Node3D).global_position - owner_hero.global_position + Vector3(0.0, 0.4, 0.0)).normalized()
						(v as RigidBody3D).apply_central_impulse(v_dir * kb_power * 45.0)
			return true

		4: # Sixth Sense: Tactical radar wall-reveal for self and nearby allies
			var sense_radius: float = 35.0 + float(rank) * 10.0
			var duration: float = 6.0 + float(rank) * 1.5
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_sixth_sense(sense_radius, duration)
			for id_key in heroes_by_id.keys():
				var ally: HeroCharacter = heroes_by_id[id_key]
				if ally != null and ally != owner_hero and not ally.is_defeated and ally.team == owner_hero.team:
					if ally.global_position.distance_to(owner_hero.global_position) <= 18.0 and ally.status_effects != null:
						ally.status_effects.activate_sixth_sense(sense_radius, duration * 0.85)
			return true

	return false
