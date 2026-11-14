class_name ClassSoldier
extends Node

## Configures Soldier class stats, loadout (SMG, Shotgun, Pistol, TNT), and SoldierSkills.
static func configure_hero(hero: HeroCharacter) -> void:
	hero.max_hp = 110
	hero.hp = 110
	hero.base_move_speed = 7.8
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
	for kind in [WeaponBase.WeaponKind.SMG, WeaponBase.WeaponKind.SHOTGUN, WeaponBase.WeaponKind.PISTOL]:
		var w := HitscanWeapon.new()
		w.configure(hero, kind, hero.archetype)
		hero.add_child(w)
		hero.weapons.append(w)

	var tnt := ProjectileWeapon.new()
	tnt.configure(hero, WeaponBase.WeaponKind.TNT, hero.archetype)
	hero.add_child(tnt)
	hero.weapons.append(tnt)
