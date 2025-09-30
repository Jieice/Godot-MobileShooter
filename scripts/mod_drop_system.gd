extends Node

# MOD掉落系统
# 管理MOD的掉落概率、品质分布和获取逻辑

signal mod_dropped(mod_id, enemy_type)

# 掉落概率配置
const DROP_CHANCES = {
	"normal": 0.05, # 普通敌人 5%
	"elite": 0.15, # 精英敌人 15%
	"boss": 0.35 # BOSS 35%
}

# 品质掉落权重（根据敌人类型）
const RARITY_WEIGHTS = {
	"normal": {
		ModSystem.ModRarity.COMMON: 80,
		ModSystem.ModRarity.RARE: 20,
		ModSystem.ModRarity.EPIC: 0,
		ModSystem.ModRarity.LEGENDARY: 0
	},
	"elite": {
		ModSystem.ModRarity.COMMON: 50,
		ModSystem.ModRarity.RARE: 35,
		ModSystem.ModRarity.EPIC: 15,
		ModSystem.ModRarity.LEGENDARY: 0
	},
	"boss": {
		ModSystem.ModRarity.COMMON: 20,
		ModSystem.ModRarity.RARE: 40,
		ModSystem.ModRarity.EPIC: 30,
		ModSystem.ModRarity.LEGENDARY: 10
	}
}

# 可掉落的MOD池（按品质分类）
var drop_pools = {
	ModSystem.ModRarity.COMMON: [
		"high_speed_shooting",
		"range_amplifier",
		"penetration_enhancement"
	],
	ModSystem.ModRarity.RARE: [
		"shield_enhancement"
	],
	ModSystem.ModRarity.EPIC: [
		"elite_killer",
		"life_siphon"
	],
	ModSystem.ModRarity.LEGENDARY: [
		"chain_reaction"
	]
}

# 新增的MOD定义
var additional_mods = {}

func _ready():
	add_to_group("mod_drop_system")
	initialize_additional_mods()

# 初始化额外的MOD定义
func initialize_additional_mods():
	# 添加更多MOD到掉落池
	add_mod_to_pool("damage_boost", ModSystem.ModRarity.COMMON, "伤害强化", "增加基础伤害", 6, 5, [ {"attribute": "bullet_damage", "value": 2, "level": 1}])
	add_mod_to_pool("crit_enhancement", ModSystem.ModRarity.RARE, "暴击强化", "增加暴击几率和暴击伤害", 8, 3, [ {"attribute": "crit_chance", "value": 0.05, "level": 1}])
	add_mod_to_pool("multi_shot", ModSystem.ModRarity.EPIC, "多重射击", "增加多连发几率", 10, 3, [ {"attribute": "double_shot_chance", "value": 0.1, "level": 1}])
	add_mod_to_pool("vampiric_strike", ModSystem.ModRarity.LEGENDARY, "吸血打击", "攻击时恢复生命值", 12, 3, [ {"attribute": "vampiric_enabled", "value": true, "level": 1}])
	add_mod_to_pool("explosive_rounds", ModSystem.ModRarity.EPIC, "爆炸弹头", "子弹命中时产生小范围爆炸", 9, 2, [ {"attribute": "explosive_enabled", "value": true, "level": 1}])
	add_mod_to_pool("ice_rounds", ModSystem.ModRarity.RARE, "冰冻弹头", "子弹有几率冰冻敌人", 7, 3, [ {"attribute": "ice_chance", "value": 0.15, "level": 1}])
	add_mod_to_pool("poison_rounds", ModSystem.ModRarity.RARE, "毒液弹头", "子弹有几率使敌人中毒", 7, 3, [ {"attribute": "poison_chance", "value": 0.15, "level": 1}])
	add_mod_to_pool("lightning_chain", ModSystem.ModRarity.LEGENDARY, "闪电链", "子弹可以在敌人间跳跃", 15, 2, [ {"attribute": "lightning_chain_enabled", "value": true, "level": 1}])

# 添加MOD到掉落池
func add_mod_to_pool(mod_id: String, rarity: ModSystem.ModRarity, mod_name: String, description: String, capacity_cost: int, max_level: int, effects: Array):
	# 创建MOD数据
	var mod_data = ModSystem.ModData.new()
	mod_data.id = mod_id
	mod_data.name = mod_name
	mod_data.description = description
	mod_data.rarity = rarity
	mod_data.base_capacity_cost = capacity_cost
	mod_data.max_level = max_level
	mod_data.effects = effects
	
	# 设置极性（随机）
	var polarities = [ModSystem.ModPolarity.BLUE, ModSystem.ModPolarity.RED, ModSystem.ModPolarity.GREEN]
	mod_data.polarity = polarities[randi() % polarities.size()]
	
	# 设置MOD类型
	if "enabled" in mod_id or "chain" in mod_id:
		mod_data.mod_type = ModSystem.ModType.SPECIAL
	elif "damage" in mod_id or "crit" in mod_id or "shot" in mod_id:
		mod_data.mod_type = ModSystem.ModType.CORE
	else:
		mod_data.mod_type = ModSystem.ModType.AUXILIARY
	
	# 添加到MOD系统定义
	ModSystem.mod_definitions[mod_id] = mod_data
	
	# 添加到掉落池
	if not rarity in drop_pools:
		drop_pools[rarity] = []
	drop_pools[rarity].append(mod_id)

# 计算掉落概率
func calculate_drop_chance(is_boss: bool, is_elite: bool) -> float:
	var enemy_type = "normal"
	if is_boss:
		enemy_type = "boss"
	elif is_elite:
		enemy_type = "elite"
	
	return DROP_CHANCES[enemy_type]

# 选择掉落的MOD
func select_drop_mod(is_boss: bool, is_elite: bool) -> String:
	var enemy_type = "normal"
	if is_boss:
		enemy_type = "boss"
	elif is_elite:
		enemy_type = "elite"
	
	# 根据敌人类型选择品质
	var rarity = select_rarity(enemy_type)
	
	# 从对应品质的MOD池中选择
	if rarity in drop_pools and drop_pools[rarity].size() > 0:
		var mod_pool = drop_pools[rarity]
		var selected_mod = mod_pool[randi() % mod_pool.size()]
		
		# 发出掉落信号
		emit_signal("mod_dropped", selected_mod, enemy_type)
		
		return selected_mod
	
	return ""

# 根据敌人类型选择品质
func select_rarity(enemy_type: String) -> ModSystem.ModRarity:
	var weights = RARITY_WEIGHTS[enemy_type]
	var total_weight = 0
	
	# 计算总权重
	for rarity in weights:
		total_weight += weights[rarity]
	
	# 随机选择
	var random_value = randi() % total_weight
	var current_weight = 0
	
	for rarity in weights:
		current_weight += weights[rarity]
		if random_value < current_weight:
			return rarity
	
	# 默认返回普通品质
	return ModSystem.ModRarity.COMMON

# 获取掉落统计信息
func get_drop_statistics() -> Dictionary:
	return {
		"drop_chances": DROP_CHANCES,
		"rarity_weights": RARITY_WEIGHTS,
		"total_mods": get_total_mod_count()
	}

# 获取总MOD数量
func get_total_mod_count() -> int:
	var total = 0
	for rarity in drop_pools:
		total += drop_pools[rarity].size()
	return total

# 根据玩家等级调整掉落概率
func adjust_drop_chance_for_level(player_level: int) -> float:
	# 等级越高，掉落概率略微增加
	var level_bonus = min(player_level * 0.001, 0.05) # 最多增加5%
	return 1.0 + level_bonus

# 检查MOD是否已拥有
func is_mod_already_owned(mod_id: String) -> bool:
	return mod_id in ModSystem.mod_inventory

# 获取稀有MOD掉落概率（用于UI显示）
func get_rare_drop_chance(enemy_type: String) -> float:
	if not enemy_type in RARITY_WEIGHTS:
		return 0.0
	
	var weights = RARITY_WEIGHTS[enemy_type]
	var total_weight = 0
	var rare_weight = 0
	
	for rarity in weights:
		total_weight += weights[rarity]
		if rarity in [ModSystem.ModRarity.EPIC, ModSystem.ModRarity.LEGENDARY]:
			rare_weight += weights[rarity]
	
	if total_weight == 0:
		return 0.0
	
	return float(rare_weight) / float(total_weight)
