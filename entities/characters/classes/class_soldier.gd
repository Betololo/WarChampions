class_name ClassSoldier
extends Node

## Configures Soldier class stats, loadout (SMG, Shotgun, Pistol, TNT), and SoldierSkills.
static func configure_hero(hero: HeroCharacter) -> void:
	hero.max_hp = 110
	hero.hp = 110
	hero.base_move_speed = 6.3
	hero.capsule_radius = 0.42

	var se := StatusEffectContainer.new()
	se.name = "StatusEffects"
	hero.add_child(se)
	hero.status_effects = se

	var sm := SoldierSkills.new()
	sm.name = "SkillManager"
	hero.add_child(sm)
	hero.skill_manager = sm

	hero.weapons.clear()
	var kinds: Array[int] = [WeaponBase.WeaponKind.SMG, WeaponBase.WeaponKind.SHOTGUN, WeaponBase.WeaponKind.PISTOL]
	for s_idx in range(kinds.size()):
		var w := HitscanWeapon.new()
		w.configure(hero, kinds[s_idx], int(hero.weapon_slot_archetypes.get(s_idx, hero.archetype)))
		hero.add_child(w)
		hero.weapons.append(w)

	var tnt := ProjectileWeapon.new()
	tnt.configure(hero, WeaponBase.WeaponKind.TNT, int(hero.weapon_slot_archetypes.get(3, hero.archetype)))
	hero.add_child(tnt)
	hero.weapons.append(tnt)
