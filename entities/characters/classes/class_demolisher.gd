class_name ClassDemolisher
extends Node

## Configures Demolisher class stats (110 HP, 5.4 m/s), loadout (Flamethrower, Grenade Launcher, Stick Grenade), and DemolisherSkills.
const CLASS_NAME: String = "Demolisher"
const BASE_HP: int = 110
const BASE_SPEED: float = 5.4
const FLAME_WEAPON_SCRIPT: GDScript = preload("res://entities/weapons/flame_weapon.gd")


static func create_weapons(owner_hero: HeroCharacter, slot_archetypes: Dictionary = {}) -> Array[WeaponBase]:
	var out: Array[WeaponBase] = []
	var default_arch: int = owner_hero.archetype if owner_hero != null else 0

	var flame: WeaponBase = FLAME_WEAPON_SCRIPT.new() as WeaponBase
	flame.configure(owner_hero, WeaponBase.WeaponKind.FLAMETHROWER, int(slot_archetypes.get(0, default_arch)))
	out.append(flame)

	var launcher := ProjectileWeapon.new()
	launcher.configure(owner_hero, WeaponBase.WeaponKind.GRENADE_LAUNCHER, int(slot_archetypes.get(1, default_arch)))
	out.append(launcher)

	var caber := HitscanWeapon.new()
	caber.configure(owner_hero, WeaponBase.WeaponKind.STICK_GRENADE, int(slot_archetypes.get(2, 0)))
	out.append(caber)

	return out


static func configure_hero(hero: HeroCharacter) -> void:
	hero.max_hp = BASE_HP
	hero.hp = BASE_HP
	hero.base_move_speed = BASE_SPEED
	hero.capsule_radius = 0.46

	var se := StatusEffectContainer.new()
	se.name = "StatusEffects"
	hero.add_child(se)
	hero.status_effects = se

	var sm := DemolisherSkills.new()
	sm.name = "SkillManager"
	hero.add_child(sm)
	hero.skill_manager = sm

	hero.weapons.clear()
	for w in create_weapons(hero, hero.weapon_slot_archetypes):
		hero.add_child(w)
		hero.weapons.append(w)
