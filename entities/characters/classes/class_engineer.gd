class_name ClassEngineer
extends RefCounted

## Field Engineer Class:
## - HP: 125, Move speed: 6.3 m/s
## - Slot 0: Dual Revolvers (arch 0) or Dual Pistols (arch 1+)
## - Slot 1: Shotgun (Balanced / Short / Long)
## - Slot 2: Welding Torch (heals empty/allied vehicles, damages enemy vehicles & enemy heroes)
## - Skills: EngineerSkills (Trench, Shielded MG Turret, Armor Vehicle, Minimap Mortar, 1.5s Invulnerability)

const EngineerSkillsScript := preload("res://entities/skills/engineer_skills.gd")
const HitscanWeaponScript := preload("res://entities/weapons/hitscan_weapon.gd")
const WeldingWeaponScript := preload("res://entities/weapons/welding_weapon.gd")

const BASE_HP: int = 125
const BASE_SPEED: float = 6.3


static func configure_hero(hero: HeroCharacter) -> void:
	hero.class_id = NetworkManager.CLASS_ENGINEER
	hero.max_hp = BASE_HP
	hero.hp = BASE_HP
	hero.base_move_speed = BASE_SPEED
	hero.capsule_radius = 0.43

	if hero.status_effects == null:
		var se := StatusEffectContainer.new()
		se.name = "StatusEffects"
		hero.add_child(se)
		hero.status_effects = se

	if hero.skill_manager == null:
		var sm := EngineerSkillsScript.new() as EngineerSkills
		sm.name = "SkillManager"
		hero.add_child(sm)
		hero.skill_manager = sm

	hero.weapons.clear()
	for w in create_weapons(hero, hero.weapon_slot_archetypes):
		hero.add_child(w)
		hero.weapons.append(w)


static func create_weapons(hero: HeroCharacter, slot_archetypes: Dictionary = {}) -> Array[WeaponBase]:
	var arch0: int = clampi(int(slot_archetypes.get(0, hero.archetype)), 0, 2)
	var arch1: int = clampi(int(slot_archetypes.get(1, hero.archetype)), 0, 2)

	var w0 := HitscanWeaponScript.new() as HitscanWeapon
	var dual_kind: int = WeaponBase.WeaponKind.DUAL_REVOLVERS if arch0 == 0 else WeaponBase.WeaponKind.DUAL_PISTOLS
	w0.configure(hero, dual_kind, arch0)

	var w1 := HitscanWeaponScript.new() as HitscanWeapon
	w1.configure(hero, WeaponBase.WeaponKind.SHOTGUN, arch1)

	var w2 := WeldingWeaponScript.new() as WeldingWeapon
	w2.configure(hero, WeaponBase.WeaponKind.WELDING_TORCH, NetworkManager.ARCHETYPE_BALANCED)

	return [w0, w1, w2]
