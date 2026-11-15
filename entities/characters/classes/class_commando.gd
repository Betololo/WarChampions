class_name ClassCommando
extends Node

## Configures Commando class stats (80 HP, fast, slim hitbox), loadout (Sniper, Knife, Pistol, TNT), and CommandoSkills.
static func configure_hero(hero: HeroCharacter) -> void:
	hero.max_hp = 80
	hero.hp = 80
	hero.base_move_speed = 7.2
	hero.capsule_radius = 0.36

	var se := StatusEffectContainer.new()
	se.name = "StatusEffects"
	hero.add_child(se)
	hero.status_effects = se

	var sm := CommandoSkills.new()
	sm.name = "SkillManager"
	hero.add_child(sm)
	hero.skill_manager = sm

	hero.weapons.clear()
	var kinds: Array[int] = [WeaponBase.WeaponKind.SNIPER, WeaponBase.WeaponKind.KNIFE, WeaponBase.WeaponKind.PISTOL]
	for s_idx in range(kinds.size()):
		var w := HitscanWeapon.new()
		w.configure(hero, kinds[s_idx], int(hero.weapon_slot_archetypes.get(s_idx, hero.archetype)))
		hero.add_child(w)
		hero.weapons.append(w)

	var tnt := ProjectileWeapon.new()
	tnt.configure(hero, WeaponBase.WeaponKind.TNT, int(hero.weapon_slot_archetypes.get(3, hero.archetype)))
	hero.add_child(tnt)
	hero.weapons.append(tnt)
