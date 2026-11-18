class_name SkillCatalog
extends RefCounted

## Canonical shared metadata for all 16 Rank-5 heroic class skills and 4 consumable widgets.
## Used by HUD hotbar tooltips and the ClassSelectMenu "Habilidades das Classes" encyclopedia.

const SOLDIER_SKILLS: Array[Dictionary] = [
	{
		"icon": "icon_skill_0_0",
		"name": "Combat Medicine",
		"category": "Cura em Área",
		"cooldown": "13s",
		"duration": "3.0s (HoT)",
		"area": "Raio 12m",
		"effect_stats": "+60 HP imediato + 36 HP em 3s",
		"description": "Cura você e aliados próximos instantaneamente e continua regenerando.",
		"aoe_radius": 12.0,
	},
	{
		"icon": "icon_skill_0_1",
		"name": "Burning Bullets",
		"category": "Buff Pessoal",
		"cooldown": "16s",
		"duration": "9.0s",
		"area": "Individual",
		"effect_stats": "+16 dano fogo/s",
		"description": "Incendeia inimigos atingidos pelos seus disparos durante a duração.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_0_2",
		"name": "Grenade Spam",
		"category": "Explosivo Frontal",
		"cooldown": "18s",
		"duration": "Instantâneo",
		"area": "5 granadas",
		"effect_stats": "5 granadas em leque",
		"description": "Arremessa uma salva de 5 granadas explosivas à frente.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_0_3",
		"name": "Blasting Strike",
		"category": "Área / Controle",
		"cooldown": "14s",
		"duration": "Instantâneo",
		"area": "Raio 13m",
		"effect_stats": "30 dano + forte repulsão",
		"description": "Onda de choque que fere e arremessa inimigos e veículos leves para longe.",
		"aoe_radius": 13.0,
	},
	{
		"icon": "icon_skill_0_4",
		"name": "Sixth Sense",
		"category": "Área / Radar",
		"cooldown": "20s",
		"duration": "13.5s",
		"area": "Aliados 18m / Pulso 55m",
		"effect_stats": "Pulso X-Ray em Raio (55m)",
		"description": "Emite pulsos ao redor revelando todos os inimigos no raio de 55m (mesmo atrás de paredes ou invisíveis).",
		"aoe_radius": 18.0,
	},
]

const GUNNER_SKILLS: Array[Dictionary] = [
	{
		"icon": "icon_skill_1_0",
		"name": "Hero Shield",
		"category": "Buff Pessoal",
		"cooldown": "16s",
		"duration": "11.0s",
		"area": "Individual",
		"effect_stats": "+155 Escudo",
		"description": "Gera um escudo azul de energia que absorve dano antes da vida.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_1_1",
		"name": "Leg It",
		"category": "Área / Buff",
		"cooldown": "15s",
		"duration": "8.0s",
		"area": "Raio 11m",
		"effect_stats": "+68% Velocidade (1.68x)",
		"description": "Acelera você e todos os aliados na área ao redor.",
		"aoe_radius": 11.0,
	},
	{
		"icon": "icon_skill_1_2",
		"name": "Explosive Keg",
		"category": "Explosivo em Área",
		"cooldown": "18s",
		"duration": "5.0s (Slow)",
		"area": "Raio ~7m",
		"effect_stats": "95 dano + -40% Vel / -50% Mira",
		"description": "Lança barril explosivo que causa dano em área e atordoa inimigos.",
		"aoe_radius": 7.5,
	},
	{
		"icon": "icon_skill_1_3",
		"name": "Frenzy Fire",
		"category": "Buff Pessoal",
		"cooldown": "17s",
		"duration": "11.0s",
		"area": "Individual",
		"effect_stats": "Precisão MG + +16 HP / 4 acertos",
		"description": "Melhora precisão da metralhadora e cura ao acertar inimigos.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_1_4",
		"name": "I Eat Grenades",
		"category": "Buff Pessoal",
		"cooldown": "20s",
		"duration": "8.0s",
		"area": "Individual",
		"effect_stats": "Absorve explosivos em HP",
		"description": "Converte dano de granadas e explosivos em cura direta.",
		"aoe_radius": 0.0,
	},
]

const COMMANDO_SKILLS: Array[Dictionary] = [
	{
		"icon": "icon_skill_2_0",
		"name": "Stealth",
		"category": "Furtividade",
		"cooldown": "15s (ao sair)",
		"duration": "Contínua",
		"area": "Detecção < 4m",
		"effect_stats": "Camuflagem invisível",
		"description": "Fica invisível até atacar, receber >15 de dano ou ser marcado.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_2_1",
		"name": "Piercing Shot",
		"category": "Buff Pessoal",
		"cooldown": "14s",
		"duration": "10.0s",
		"area": "Individual",
		"effect_stats": "2.1x dano + Perfuração",
		"description": "Tiros de Sniper atravessam múltiplos alvos alinhados com dano bônus.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_2_2",
		"name": "Poisoned Blade",
		"category": "Buff Pessoal",
		"cooldown": "14s",
		"duration": "13.0s",
		"area": "Individual",
		"effect_stats": "Envenena por 6.0s (+25 dano/s em ticks de 0.5s)",
		"description": "Envenena a faca causando dano contínuo intenso ao cortar inimigos.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_2_3",
		"name": "Troop Trap",
		"category": "Armadilha / Área",
		"cooldown": "16s",
		"duration": "60.0s (máx 2)",
		"area": "Raio 5.5m",
		"effect_stats": "115 dano + Repulsão",
		"description": "Planta até 2 minas terrestres que detonam ao aproximar inimigos.",
		"aoe_radius": 5.5,
	},
	{
		"icon": "icon_skill_2_4",
		"name": "Elixir",
		"category": "Buff Pessoal",
		"cooldown": "18s",
		"duration": "7.5s",
		"area": "Individual",
		"effect_stats": "+75% Vel (1.75x) + 60 Escudo",
		"description": "Soro de adrenalina que aumenta velocidade e dá escudo protetor.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_2_5",
		"name": "Mark Target",
		"category": "Marcação Tática",
		"cooldown": "20s",
		"duration": "12.0s marca",
		"area": "1 Alvo na Mira (Visão)",
		"effect_stats": "X-Ray global + quebra Stealth",
		"description": "Marca 1 inimigo ou veículo sob a mira na linha de visão (sem limite de distância) por 12s.",
		"aoe_radius": 0.0,
	},
]

const DEMOLISHER_SKILLS: Array[Dictionary] = [
	{
		"icon": "icon_skill_3_0",
		"name": "Escudo Balístico (Em Mãos)",
		"category": "Defesa / Combate",
		"cooldown": "16s (ao guardar/quebrar)",
		"duration": "Até guardar ou 150 HP",
		"area": "Arco frontal",
		"effect_stats": "150 HP + Granada de Cabo",
		"description": "Empunha o Escudo Balístico frontal (150 HP) e equipa a Granada de Cabo; atacar abre brecha rápida.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_3_1",
		"name": "Haste",
		"category": "Buff Pessoal",
		"cooldown": "16s",
		"duration": "6.0s",
		"area": "Individual",
		"effect_stats": "+38% Vel / +50% Cadência / +60% Recarga",
		"description": "Adrenalina que acelera movimento, cadência de tiro e velocidade de recarga.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_3_2",
		"name": "Corda de TNTs",
		"category": "Explosivo Pesado",
		"cooldown": "15s (ao lançar)",
		"duration": "Sem limite",
		"area": "Raio 9m",
		"effect_stats": "Salva pesada de TNTs",
		"description": "Prepara um feixe de TNTs na mão sem limite de tempo até você clicar para lançar.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_3_3",
		"name": "Kit de 5 Coletes",
		"category": "Suporte / Armadura",
		"cooldown": "17s (ao esvaziar)",
		"duration": "5 coletes no chão",
		"area": "Raio 2.0m",
		"effect_stats": "+70 Escudo Permanente (5x)",
		"description": "Solta no chão um kit com 5 coletes (+70 de escudo permanente até sofrer dano) para aliados e você.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_skill_3_4",
		"name": "Quebra-Tanques",
		"category": "Buff Antiveículo",
		"cooldown": "18s",
		"duration": "3.0s",
		"area": "Individual",
		"effect_stats": "3x Dano em Veículos",
		"description": "Triplica todo o dano causado contra veículos por 3.0s.",
		"aoe_radius": 0.0,
	},
]

const WIDGETS: Array[Dictionary] = [
	{
		"icon": "icon_widget_0",
		"name": "Bandagens",
		"category": "Consumível",
		"cooldown": "15s",
		"duration": "2.0s (Canal)",
		"area": "Individual",
		"effect_stats": "+40 HP",
		"description": "Canaliza 2.0s para recuperar +40 HP (interrompida por dano direto).",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_widget_1",
		"name": "Chave Inglesa",
		"category": "Consumível",
		"cooldown": "8s",
		"duration": "Instantâneo",
		"area": "Alcance 8m",
		"effect_stats": "+110 HP Veículo",
		"description": "Repara +110 HP em veículo aliado próximo ou em que você estiver.",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_widget_2",
		"name": "Água",
		"category": "Consumível",
		"cooldown": "14s",
		"duration": "2.0s",
		"area": "Individual",
		"effect_stats": "Limpa fogo + Imunidade",
		"description": "Limpa Afterburn/Fogo e concede imunidade a chamas por 2.0s",
		"aoe_radius": 0.0,
	},
	{
		"icon": "icon_widget_3",
		"name": "Antídoto",
		"category": "Consumível",
		"cooldown": "14s",
		"duration": "Instantâneo",
		"area": "Individual",
		"effect_stats": "Remove veneno",
		"description": "Remove veneno e tela verde na hora.",
		"aoe_radius": 0.0,
	},
]


static func get_class_skills(class_id: int) -> Array[Dictionary]:
	var src: Array[Dictionary]
	match class_id:
		NetworkManager.CLASS_SOLDIER:
			src = SOLDIER_SKILLS
		NetworkManager.CLASS_GUNNER:
			src = GUNNER_SKILLS
		NetworkManager.CLASS_COMMANDO:
			src = COMMANDO_SKILLS
		NetworkManager.CLASS_DEMOLISHER:
			src = DEMOLISHER_SKILLS
		_:
			return []
	var out: Array[Dictionary] = []
	for item in src:
		out.append(item.duplicate())
	return out


static func get_widgets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in WIDGETS:
		out.append(item.duplicate())
	return out


static func get_entry_by_key(icon_key: String) -> Dictionary:
	for arr in [SOLDIER_SKILLS, GUNNER_SKILLS, COMMANDO_SKILLS, DEMOLISHER_SKILLS, WIDGETS]:
		for item in arr:
			if str(item.get("icon", "")) == icon_key:
				return item.duplicate()
	return {}
