extends Node

# 游戏属性
# 存储和管理游戏中的各种属性和数值

signal attributes_changed(attribute_name, value)
signal diamonds_changed(new_diamonds) # 新增信号，表示钻石数量已更改

# 玩家属性
var player_speed = 300
var health = 100
var max_health = 100
var bullet_damage = 10
var bullet_cooldown = 0.5
var defense = 0.0 # 防御值，减少受到的伤害（0-1之间）
var penetration = 0.0 # 防御穿透率，无视目标一定比例的防御（0-1之间）
var auto_fire = true # 自动发射子弹

# 天赋系统相关属性
var attack_range = 1.0
var penetration_count = 0
var crit_chance = 0.0 # 暴击几率
var crit_multiplier = 1.5 # 暴击倍率
var double_shot_chance = 0.0 # 双连发几率
var triple_shot_chance = 0.0 # 三连发几率
var crush_chance = 0.0 # 压碎性打击几率
var crush_boss_bonus = 0.0 # BOSS压碎加成
var bleed_chance = 0.0 # 撕裂几率
var bleed_damage_per_second = 0.0 # 流血伤害/秒
var bleed_duration = 0.0 # 流血持续时间
var fission_chance = 0.0 # 裂变几率
var dodge_chance = 0.0 # 闪避率
var attack_speed = 1.0 # 攻击速度倍率
var last_stand_shield_enabled = false
var last_stand_shield_duration = 0.0
var last_stand_shield_threshold = 0.0
var elite_priority_chance = 0.0
var kill_energy_chance = 0.0
var dual_target_enabled = false
var chain_lightning_chance = 0.0
var bullet_damage_multiplier = 1.0
var bullet_lifetime = 2.0
var fission_range = 1.0
var is_fission_enabled = false # 是否启用裂变效果
var max_fission_level = 2 # 最大裂变等级
var fission_count = 2 # 裂变子弹数量
var fission_damage_ratio = 0.5 # 裂变子弹伤害比例

# 模块槽系统
var core_modules = []
var auxiliary_modules = []
var special_modules = []


# 子弹基础属性
var bullet_speed = 400

# 钻石系统
var diamonds = 0 # 钻石数量

# 游戏分数和天赋点
var score = 0 # 游戏分数
var talent_points = 0 # 天赋点数

# 初始化
func _ready():
	print("GameAttributes: _ready() called")
	# 添加到自动加载单例组
	add_to_group("game_attributes")
	
	# 初始化属性
	initialize_attributes()
	
	# *** 临时修改玩家等级用于测试 ***
	# player_level = 10


# 初始化属性
func initialize_attributes():
	print("GameAttributes: initialize_attributes() called")
	# 重置所有属性为默认值
	var _all_attributes = {
		"bullet_damage": 10, # 基础子弹伤害
		"bullet_cooldown": 0.5,
		"defense": 0.0,
		"penetration": 0.0,
		"auto_fire": true,
		"attack_range": 1.0,
		"penetration_count": 0,
		"crit_chance": 0.1, # 修正初始暴击率为 10%
		"crit_multiplier": 1.5,
		"double_shot_chance": 0.0,
		"triple_shot_chance": 0.0,
		"crush_chance": 0.0,
		"crush_boss_bonus": 0.0,
		"bleed_chance": 0.0,
		"bleed_damage_per_second": 0.0,
		"bleed_duration": 0.0,
		"fission_chance": 0.0,
		"dodge_chance": 0.0,
		"attack_speed": 1.0,
		"last_stand_shield_enabled": false,
		"last_stand_shield_duration": 0.0,
		"last_stand_shield_threshold": 0.0,
		"elite_priority_chance": 0.0,
		"kill_energy_chance": 0.0,
		"dual_target_enabled": false,
		"chain_lightning_chance": 0.0,
		"bullet_damage_multiplier": 1.0,
		"bullet_lifetime": 2.0,
		"fission_range": 1.0,
		"is_fission_enabled": false,
		"max_fission_level": 2,
		"fission_count": 2,
		"fission_damage_ratio": 0.5,
		"bullet_speed": 400,
		"diamonds": 0,
		"score": 0,
		"talent_points": 0,
		"player_speed": 300,
		"health": 100,
		"max_health": 100,
	}

# 增加属性值
func increase_attribute(attribute_name, amount):
	if get(attribute_name) != null:
		var new_value = get(attribute_name) + amount
		set(attribute_name, new_value)
		print("增加属性 ", attribute_name, " 值: ", amount, " 当前值: ", new_value)
		emit_signal("attributes_changed", attribute_name, new_value)
		if attribute_name == "diamonds": # 如果是钻石属性，发出专用信号
			emit_signal("diamonds_changed", new_value)
		return true
	print("属性不存在: ", attribute_name)
	return false

# 更新属性值
func update_attribute(attribute_name, value):
	if get(attribute_name) != null:
		set(attribute_name, value)
		print("GameAttributes: 更新属性 ", attribute_name, " 为: ", value)
		emit_signal("attributes_changed", attribute_name, value)
		if attribute_name == "diamonds": # 如果是钻石属性，发出专用信号
			emit_signal("diamonds_changed", value)
		return true
	print("GameAttributes: 属性不存在: ", attribute_name)
	return false

# 获取属性值
func get_attribute(attribute_name):
	if get(attribute_name) != null:
		return get(attribute_name)
	print("属性不存在: ", attribute_name)
	return null
