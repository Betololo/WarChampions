class_name ClassGunner
extends Node

## Configures Gunner class stats (150 HP, slow, larger hitbox), loadout (MG, Shotgun, Bazooka), and GunnerSkills.
static func configure_hero(hero: HeroCharacter) -> void:
	hero.max_hp = 150
	hero.hp = 150
	hero.base_move_speed = 5.4
	hero.capsule_radius = 0.56

	var se := StatusEffectContainer.new()
	se.name = "StatusEffects"
	hero.add_child(se)
	hero.status_effects = se

	var sm := GunnerSkills.new()
	sm.name = "SkillManager"
	hero.add_child(sm)
	hero.skill_manager = sm

	hero.weapons.clear()
	var kinds: Array[int] = [WeaponBase.WeaponKind.MG, WeaponBase.WeaponKind.SHOTGUN]
	for s_idx in range(kinds.size()):
		var w := HitscanWeapon.new()
		w.configure(hero, kinds[s_idx], int(hero.weapon_slot_archetypes.get(s_idx, hero.archetype)))
		hero.add_child(w)
		hero.weapons.append(w)

	var bazooka := ProjectileWeapon.new()
	bazooka.configure(hero, WeaponBase.WeaponKind.BAZOOKA, int(hero.weapon_slot_archetypes.get(2, hero.archetype)))
	hero.add_child(bazooka)
	hero.weapons.append(bazooka)
