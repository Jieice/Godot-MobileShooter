extends Node

# MOD系统核心脚本
# 基于Warframe风格的MOD装备系统

signal mod_equipped(mod_id, slot_type)
signal mod_unequipped(mod_id, slot_type)
signal capacity_changed(new_capacity, used_capacity)

# MOD极性枚举
enum ModPolarity {
	BLUE, # 🔵 蓝色 - 核心属性
	RED, # 🟥 红色 - 攻击属性
	GREEN, # 🟢 绿色 - 特殊属性
	NEUTRAL # ⚪ 中性 - 无极性
}

# MOD品质枚举
enum ModRarity {
	COMMON, # 普通 - 白色
	RARE, # 稀有 - 蓝色
	EPIC, # 史诗 - 紫色
	LEGENDARY # 传说 - 金色
}

# MOD类型枚举
enum ModType {
	CORE, # 核心Mod - 主攻属性
	AUXILIARY, # 辅助Mod - 功能增益
	SPECIAL # 特效Mod - 触发机制
}

# 核心模块类型
enum CoreModuleType {
	BASIC_TURRET, # 基础炮台 (1-10级)
	ENERGY_CORE, # 聚能核心 (10-20级)
	ANNIHILATION_MATRIX # 湮灭矩阵 (20-30级)
}

# MOD数据结构
class ModData:
	var id: String
	var name: String
	var description: String
	var polarity: ModPolarity
	var rarity: ModRarity
	var mod_type: ModType
	var base_capacity_cost: int
	var max_level: int
	var current_level: int = 0
	var effects: Array = [] # [{attribute: "attack_speed", value: 0.1, level: 1}]
	var trigger_condition: String = "" # 特效Mod的触发条件
	var trigger_effect: Dictionary = {} # 特效Mod的效果

# 核心模块数据结构
class CoreModule:
	var type: CoreModuleType
	var name: String
	var description: String
	var required_level: int
	var max_capacity: int
	var polarity_slots: Array = []
	var equipped_mods: Dictionary = {} # {slot_index: mod_id}

# 玩家MOD状态
var player_mods: Dictionary = {} # {mod_id: ModData}
var player_core_module: CoreModule
var mod_inventory: Array[String] = [] # 拥有的MOD ID列表

# MOD定义数据库
var mod_definitions: Dictionary = {}
var core_module_definitions: Dictionary = {}

func _ready():
	add_to_group("mod_system")
	initialize_mod_definitions()
	initialize_core_modules()
	setup_initial_core_module()

# 初始化MOD定义
func initialize_mod_definitions():
	# 核心Mod定义
	mod_definitions["high_speed_shooting"] = ModData.new()
	mod_definitions["high_speed_shooting"].id = "high_speed_shooting"
	mod_definitions["high_speed_shooting"].name = "高速射击"
	mod_definitions["high_speed_shooting"].description = "提升射击速度"
	mod_definitions["high_speed_shooting"].polarity = ModPolarity.RED
	mod_definitions["high_speed_shooting"].rarity = ModRarity.COMMON
	mod_definitions["high_speed_shooting"].mod_type = ModType.CORE
	mod_definitions["high_speed_shooting"].base_capacity_cost = 6
	mod_definitions["high_speed_shooting"].max_level = 5
	mod_definitions["high_speed_shooting"].effects = [
		{"attribute": "attack_speed", "value": 0.1, "level": 1},
		{"attribute": "attack_speed", "value": 0.2, "level": 2},
		{"attribute": "attack_speed", "value": 0.3, "level": 3},
		{"attribute": "attack_speed", "value": 0.4, "level": 4},
		{"attribute": "attack_speed", "value": 0.5, "level": 5}
	]

	mod_definitions["range_amplifier"] = ModData.new()
	mod_definitions["range_amplifier"].id = "range_amplifier"
	mod_definitions["range_amplifier"].name = "范围增幅"
	mod_definitions["range_amplifier"].description = "增加攻击范围"
	mod_definitions["range_amplifier"].polarity = ModPolarity.BLUE
	mod_definitions["range_amplifier"].rarity = ModRarity.COMMON
	mod_definitions["range_amplifier"].mod_type = ModType.CORE
	mod_definitions["range_amplifier"].base_capacity_cost = 6
	mod_definitions["range_amplifier"].max_level = 5
	mod_definitions["range_amplifier"].effects = [
		{"attribute": "attack_range", "value": 0.5, "level": 1},
		{"attribute": "attack_range", "value": 1.0, "level": 2},
		{"attribute": "attack_range", "value": 1.5, "level": 3},
		{"attribute": "attack_range", "value": 2.0, "level": 4},
		{"attribute": "attack_range", "value": 2.5, "level": 5}
	]

	mod_definitions["penetration_enhancement"] = ModData.new()
	mod_definitions["penetration_enhancement"].id = "penetration_enhancement"
	mod_definitions["penetration_enhancement"].name = "穿透强化"
	mod_definitions["penetration_enhancement"].description = "增加子弹穿透数量"
	mod_definitions["penetration_enhancement"].polarity = ModPolarity.GREEN
	mod_definitions["penetration_enhancement"].rarity = ModRarity.COMMON
	mod_definitions["penetration_enhancement"].mod_type = ModType.CORE
	mod_definitions["penetration_enhancement"].base_capacity_cost = 8
	mod_definitions["penetration_enhancement"].max_level = 5
	mod_definitions["penetration_enhancement"].effects = [
		{"attribute": "penetration_count", "value": 1, "level": 1},
		{"attribute": "penetration_count", "value": 2, "level": 2},
		{"attribute": "penetration_count", "value": 3, "level": 3},
		{"attribute": "penetration_count", "value": 4, "level": 4},
		{"attribute": "penetration_count", "value": 5, "level": 5}
	]

	# 辅助Mod定义
	mod_definitions["shield_enhancement"] = ModData.new()
	mod_definitions["shield_enhancement"].id = "shield_enhancement"
	mod_definitions["shield_enhancement"].name = "护盾强化"
	mod_definitions["shield_enhancement"].description = "增加护盾值和回血效果"
	mod_definitions["shield_enhancement"].polarity = ModPolarity.BLUE
	mod_definitions["shield_enhancement"].rarity = ModRarity.RARE
	mod_definitions["shield_enhancement"].mod_type = ModType.AUXILIARY
	mod_definitions["shield_enhancement"].base_capacity_cost = 6
	mod_definitions["shield_enhancement"].max_level = 3
	mod_definitions["shield_enhancement"].effects = [
		{"attribute": "shield_value", "value": 30, "level": 1},
		{"attribute": "shield_value", "value": 60, "level": 2},
		{"attribute": "shield_value", "value": 90, "level": 3}
	]

	mod_definitions["elite_killer"] = ModData.new()
	mod_definitions["elite_killer"].id = "elite_killer"
	mod_definitions["elite_killer"].name = "精英杀手"
	mod_definitions["elite_killer"].description = "对精英敌人造成额外伤害"
	mod_definitions["elite_killer"].polarity = ModPolarity.RED
	mod_definitions["elite_killer"].rarity = ModRarity.EPIC
	mod_definitions["elite_killer"].mod_type = ModType.AUXILIARY
	mod_definitions["elite_killer"].base_capacity_cost = 7
	mod_definitions["elite_killer"].max_level = 3
	mod_definitions["elite_killer"].effects = [
		{"attribute": "elite_damage_bonus", "value": 0.12, "level": 1},
		{"attribute": "elite_damage_bonus", "value": 0.24, "level": 2},
		{"attribute": "elite_damage_bonus", "value": 0.36, "level": 3}
	]

	# 特效Mod定义
	mod_definitions["chain_reaction"] = ModData.new()
	mod_definitions["chain_reaction"].id = "chain_reaction"
	mod_definitions["chain_reaction"].name = "连锁反应"
	mod_definitions["chain_reaction"].description = "子弹穿透3个敌人时触发爆炸"
	mod_definitions["chain_reaction"].polarity = ModPolarity.GREEN
	mod_definitions["chain_reaction"].rarity = ModRarity.LEGENDARY
	mod_definitions["chain_reaction"].mod_type = ModType.SPECIAL
	mod_definitions["chain_reaction"].base_capacity_cost = 12
	mod_definitions["chain_reaction"].max_level = 3
	mod_definitions["chain_reaction"].trigger_condition = "penetration_3_enemies"
	mod_definitions["chain_reaction"].trigger_effect = {
		"type": "explosion",
		"damage": 100,
		"radius": 1.0,
		"level": 1
	}

	mod_definitions["life_siphon"] = ModData.new()
	mod_definitions["life_siphon"].id = "life_siphon"
	mod_definitions["life_siphon"].name = "生命虹吸"
	mod_definitions["life_siphon"].description = "击杀敌人时恢复生命值"
	mod_definitions["life_siphon"].polarity = ModPolarity.BLUE
	mod_definitions["life_siphon"].rarity = ModRarity.EPIC
	mod_definitions["life_siphon"].mod_type = ModType.SPECIAL
	mod_definitions["life_siphon"].base_capacity_cost = 8
	mod_definitions["life_siphon"].max_level = 3
	mod_definitions["life_siphon"].trigger_condition = "kill_enemy"
	mod_definitions["life_siphon"].trigger_effect = {
		"type": "heal_percentage",
		"value": 0.05,
		"level": 1
	}

# 初始化核心模块定义
func initialize_core_modules():
	core_module_definitions[CoreModuleType.BASIC_TURRET] = CoreModule.new()
	core_module_definitions[CoreModuleType.BASIC_TURRET].type = CoreModuleType.BASIC_TURRET
	core_module_definitions[CoreModuleType.BASIC_TURRET].name = "基础炮台"
	core_module_definitions[CoreModuleType.BASIC_TURRET].description = "基础攻击模块，1个蓝色极性插槽"
	core_module_definitions[CoreModuleType.BASIC_TURRET].required_level = 1
	core_module_definitions[CoreModuleType.BASIC_TURRET].max_capacity = 10
	core_module_definitions[CoreModuleType.BASIC_TURRET].polarity_slots = [ModPolarity.BLUE]

	core_module_definitions[CoreModuleType.ENERGY_CORE] = CoreModule.new()
	core_module_definitions[CoreModuleType.ENERGY_CORE].type = CoreModuleType.ENERGY_CORE
	core_module_definitions[CoreModuleType.ENERGY_CORE].name = "聚能核心"
	core_module_definitions[CoreModuleType.ENERGY_CORE].description = "进阶攻击模块，2个极性插槽（蓝+红）"
	core_module_definitions[CoreModuleType.ENERGY_CORE].required_level = 10
	core_module_definitions[CoreModuleType.ENERGY_CORE].max_capacity = 20
	core_module_definitions[CoreModuleType.ENERGY_CORE].polarity_slots = [ModPolarity.BLUE, ModPolarity.RED]

	core_module_definitions[CoreModuleType.ANNIHILATION_MATRIX] = CoreModule.new()
	core_module_definitions[CoreModuleType.ANNIHILATION_MATRIX].type = CoreModuleType.ANNIHILATION_MATRIX
	core_module_definitions[CoreModuleType.ANNIHILATION_MATRIX].name = "湮灭矩阵"
	core_module_definitions[CoreModuleType.ANNIHILATION_MATRIX].description = "终极攻击模块，3个极性插槽（蓝+红+绿）"
	core_module_definitions[CoreModuleType.ANNIHILATION_MATRIX].required_level = 20
	core_module_definitions[CoreModuleType.ANNIHILATION_MATRIX].max_capacity = 30
	core_module_definitions[CoreModuleType.ANNIHILATION_MATRIX].polarity_slots = [ModPolarity.BLUE, ModPolarity.RED, ModPolarity.GREEN]

# 设置初始核心模块
func setup_initial_core_module():
	var base_module = core_module_definitions[CoreModuleType.BASIC_TURRET]
	player_core_module = CoreModule.new()
	player_core_module.type = base_module.type
	player_core_module.name = base_module.name
	player_core_module.description = base_module.description
	player_core_module.required_level = base_module.required_level
	player_core_module.max_capacity = base_module.max_capacity
	player_core_module.polarity_slots = base_module.polarity_slots.duplicate()
	player_core_module.equipped_mods = {}
	
	# 添加一些测试MOD到背包
	add_mod_to_inventory("high_speed_shooting")
	add_mod_to_inventory("range_amplifier")
	add_mod_to_inventory("penetration_enhancement")
	add_mod_to_inventory("shield_enhancement")
	add_mod_to_inventory("elite_killer")
	add_mod_to_inventory("chain_reaction")
	add_mod_to_inventory("life_siphon")

# 获取MOD信息
func get_mod_info(mod_id: String) -> ModData:
	if mod_id in mod_definitions:
		return mod_definitions[mod_id]
	return null

# 获取核心模块信息
func get_core_module_info(module_type: CoreModuleType) -> CoreModule:
	if module_type in core_module_definitions:
		return core_module_definitions[module_type]
	return null

# 计算MOD容量消耗
func calculate_mod_cost(mod_id: String, slot_index: int) -> int:
	var mod = get_mod_info(mod_id)
	if not mod:
		return 0
	
	var base_cost = mod.base_capacity_cost + mod.current_level
	var slot_polarity = player_core_module.polarity_slots[slot_index]
	
	# 极性匹配时容量消耗减半
	if mod.polarity == slot_polarity:
		return int(base_cost / 2)
	
	return base_cost

# 计算已使用的容量
func calculate_used_capacity() -> int:
	var total_cost = 0
	for slot_index in player_core_module.equipped_mods:
		var mod_id = player_core_module.equipped_mods[slot_index]
		total_cost += calculate_mod_cost(mod_id, slot_index)
	return total_cost

# 检查是否可以装备MOD
func can_equip_mod(mod_id: String, slot_index: int) -> bool:
	# 检查插槽是否存在
	if slot_index >= player_core_module.polarity_slots.size():
		return false
	
	# 检查MOD是否存在
	var mod = get_mod_info(mod_id)
	if not mod:
		return false
	
	# 检查是否已拥有该MOD
	if not mod_id in mod_inventory:
		return false
	
	# 检查容量是否足够
	var cost = calculate_mod_cost(mod_id, slot_index)
	var used_capacity = calculate_used_capacity()
	
	# 如果该插槽已有MOD，先计算移除后的容量
	if slot_index in player_core_module.equipped_mods:
		var old_mod_id = player_core_module.equipped_mods[slot_index]
		used_capacity -= calculate_mod_cost(old_mod_id, slot_index)
	
	return (used_capacity + cost) <= player_core_module.max_capacity

# 装备MOD
func equip_mod(mod_id: String, slot_index: int) -> bool:
	if not can_equip_mod(mod_id, slot_index):
		return false
	
	# 移除该插槽的旧MOD
	if slot_index in player_core_module.equipped_mods:
		unequip_mod(slot_index)
	
	# 装备新MOD
	player_core_module.equipped_mods[slot_index] = mod_id
	emit_signal("mod_equipped", mod_id, slot_index)
	
	# 更新容量显示
	var used_capacity = calculate_used_capacity()
	emit_signal("capacity_changed", player_core_module.max_capacity, used_capacity)
	
	print("装备MOD: ", mod_id, " 到插槽 ", slot_index)
	return true

# 卸下MOD
func unequip_mod(slot_index: int) -> bool:
	if not slot_index in player_core_module.equipped_mods:
		return false
	
	var mod_id = player_core_module.equipped_mods[slot_index]
	player_core_module.equipped_mods.erase(slot_index)
	emit_signal("mod_unequipped", mod_id, slot_index)
	
	# 更新容量显示
	var used_capacity = calculate_used_capacity()
	emit_signal("capacity_changed", player_core_module.max_capacity, used_capacity)
	
	print("卸下MOD: ", mod_id, " 从插槽 ", slot_index)
	return true

# 升级核心模块
func upgrade_core_module(new_level: int):
	var new_module_type = CoreModuleType.BASIC_TURRET
	
	if new_level >= 20:
		new_module_type = CoreModuleType.ANNIHILATION_MATRIX
	elif new_level >= 10:
		new_module_type = CoreModuleType.ENERGY_CORE
	
	# 如果模块类型改变，需要重新设置
	if new_module_type != player_core_module.type:
		# 手动复制CoreModule属性
		var source_module = core_module_definitions[new_module_type]
		player_core_module = CoreModule.new()
		player_core_module.type = source_module.type
		player_core_module.name = source_module.name
		player_core_module.description = source_module.description
		player_core_module.required_level = source_module.required_level
		player_core_module.max_capacity = source_module.max_capacity
		player_core_module.polarity_slots = source_module.polarity_slots.duplicate()
		player_core_module.equipped_mods = {}
		print("升级核心模块到: ", player_core_module.name)
	
	# 更新容量显示
	var used_capacity = calculate_used_capacity()
	emit_signal("capacity_changed", player_core_module.max_capacity, used_capacity)

# 添加MOD到背包
func add_mod_to_inventory(mod_id: String):
	if not mod_id in mod_inventory:
		mod_inventory.append(mod_id)
		print("获得MOD: ", mod_id)

# 获取当前装备的MOD效果
func get_equipped_mod_effects() -> Dictionary:
	var effects = {}
	
	for slot_index in player_core_module.equipped_mods:
		var mod_id = player_core_module.equipped_mods[slot_index]
		var mod = get_mod_info(mod_id)
		if mod:
			# 应用MOD效果
			for effect in mod.effects:
				var attribute = effect.attribute
				var value = effect.value
				
				if not attribute in effects:
					effects[attribute] = 0
				effects[attribute] += value
	
	return effects

# 获取极性名称
func get_polarity_name(polarity: ModPolarity) -> String:
	match polarity:
		ModPolarity.BLUE:
			return "🔵"
		ModPolarity.RED:
			return "🟥"
		ModPolarity.GREEN:
			return "🟢"
		ModPolarity.NEUTRAL:
			return "⚪"
		_:
			return "❓"

# 获取品质名称
func get_rarity_name(rarity: ModRarity) -> String:
	match rarity:
		ModRarity.COMMON:
			return "普通"
		ModRarity.RARE:
			return "稀有"
		ModRarity.EPIC:
			return "史诗"
		ModRarity.LEGENDARY:
			return "传说"
		_:
			return "未知"

# 加载MOD数据（用于存档系统）
func load_mod_data(mod_data: Dictionary):
	print("加载MOD数据: ", mod_data)
	
	# 加载核心模块类型
	if "core_module_type" in mod_data:
		var module_type = mod_data.core_module_type
		if module_type in core_module_definitions:
			# 手动复制CoreModule属性
			var source_module = core_module_definitions[module_type]
			player_core_module = CoreModule.new()
			player_core_module.type = source_module.type
			player_core_module.name = source_module.name
			player_core_module.description = source_module.description
			player_core_module.required_level = source_module.required_level
			player_core_module.max_capacity = source_module.max_capacity
			player_core_module.polarity_slots = source_module.polarity_slots.duplicate()
			player_core_module.equipped_mods = {}
		else:
			# 如果模块类型不存在，使用基础模块
			var source_module = core_module_definitions[CoreModuleType.BASIC_TURRET]
			player_core_module = CoreModule.new()
			player_core_module.type = source_module.type
			player_core_module.name = source_module.name
			player_core_module.description = source_module.description
			player_core_module.required_level = source_module.required_level
			player_core_module.max_capacity = source_module.max_capacity
			player_core_module.polarity_slots = source_module.polarity_slots.duplicate()
			player_core_module.equipped_mods = {}
	
	# 加载装备的MOD
	if "equipped_mods" in mod_data:
		player_core_module.equipped_mods = mod_data.equipped_mods.duplicate()
	
	# 加载MOD背包
	if "mod_inventory" in mod_data:
		mod_inventory = mod_data.mod_inventory.duplicate()
	
	# 更新容量显示
	var used_capacity = calculate_used_capacity()
	emit_signal("capacity_changed", player_core_module.max_capacity, used_capacity)
	
	print("MOD数据加载完成")
