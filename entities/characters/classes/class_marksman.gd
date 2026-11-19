class_name ClassMarksman
extends RefCounted

## Marksman Class:
## - HP: 100, Move speed: 6.3 m/s, Capsule radius: 0.42
## - Slot 0: Assault Rifle (arch 0 = Heavy AR 30/5s/25dmg/8-shot bloom, arch 1 = Suppressed AR 30/8s/14dmg/low bloom)
## - Slot 1: Combat Shotgun (Balanced / Short / Long)
## - Slot 2: Service Pistol / Revolver (Balanced / Auto / Revolver)
## - Skills: MarksmanSkills (Sprint, Flashbang, UAV, Granada de Cabo, Last Stand)

const MarksmanSkillsScript := preload("res://entities/skills/marksman_skills.gd")
const HitscanWeaponScript := preload("res://entities/weapons/hitscan_weapon.gd")

const BASE_HP: int = 100
const BASE_SPEED: float = 6.3
const CAPSULE_RADIUS: float = 0.42


static func configure_hero(hero: HeroCharacter) -> void:
	hero.class_id = NetworkManager.CLASS_MARKSMAN
	hero.max_hp = BASE_HP
	hero.hp = BASE_HP
	hero.base_move_speed = BASE_SPEED
	hero.capsule_radius = CAPSULE_RADIUS

	if hero.status_effects == null:
		var se := StatusEffectContainer.new()
		se.name = "StatusEffects"
		hero.add_child(se)
		hero.status_effects = se

	if hero.skill_manager == null:
		var sm := MarksmanSkillsScript.new() as MarksmanSkills
		sm.name = "SkillManager"
		hero.add_child(sm)
		hero.skill_manager = sm

	hero.weapons.clear()
	for w in create_weapons(hero, hero.weapon_slot_archetypes):
		hero.add_child(w)
		hero.weapons.append(w)


static func create_weapons(hero: HeroCharacter, slot_archetypes: Dictionary = {}) -> Array[WeaponBase]:
	var default_arch: int = hero.archetype if hero != null else 0
	var arch0: int = clampi(int(slot_archetypes.get(0, default_arch)), 0, 1)
	var arch1: int = clampi(int(slot_archetypes.get(1, default_arch)), 0, 2)
	var arch2: int = clampi(int(slot_archetypes.get(2, default_arch)), 0, 2)

	var w0 := HitscanWeaponScript.new() as HitscanWeapon
	w0.configure(hero, WeaponBase.WeaponKind.ASSAULT_RIFLE, arch0)

	var w1 := HitscanWeaponScript.new() as HitscanWeapon
	w1.configure(hero, WeaponBase.WeaponKind.SHOTGUN, arch1)

	var w2 := HitscanWeaponScript.new() as HitscanWeapon
	w2.configure(hero, WeaponBase.WeaponKind.PISTOL, arch2)

	return [w0, w1, w2]
