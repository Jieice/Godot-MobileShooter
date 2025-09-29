extends Node

# 游戏属性
# 存储和管理游戏中的各种属性和数值

signal attributes_changed(attribute_name, value)

# 玩家属性
var player_level = 1
var player_experience = 0
var experience_required = 100
var player_speed = 300
var health = 100
var max_health = 100
var bullet_damage = 10
var bullet_cooldown = 0.5
var defense = 0.0  # 防御值，减少受到的伤害（0-1之间）
var penetration = 0.0  # 防御穿透率，无视目标一定比例的防御（0-1之间）
var auto_fire = true  # 自动发射子弹

# 天赋系统相关属性
var attack_range = 1.0
var penetration_count = 0
var crit_chance = 0.0  # 暴击几率
var double_shot_chance = 0.0  # 双连发几率
var triple_shot_chance = 0.0  # 三连发几率
var crush_chance = 0.0  # 压碎性打击几率
var crush_boss_bonus = 0.0  # BOSS压碎加成
var bleed_chance = 0.0  # 撕裂几率
var bleed_damage_per_second = 0.0  # 流血伤害/秒
var bleed_duration = 0.0  # 流血持续时间
var fission_chance = 0.0  # 裂变几率
var dodge_chance = 0.0  # 闪避率
var attack_speed = 1.0  # 攻击速度倍率
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
var is_fission_enabled = false  # 是否启用裂变效果
var max_fission_level = 2  # 最大裂变等级
var fission_count = 2  # 裂变子弹数量
var fission_damage_ratio = 0.5  # 裂变子弹伤害比例

# 模块槽系统
var core_modules = []
var auxiliary_modules = []
var special_modules = []

# 子弹基础属性
var bullet_speed = 400

# 初始化
func _ready():
	# 添加到自动加载单例组
	add_to_group("game_attributes")

# 增加属性值
func increase_attribute(attribute_name, amount):
	if get(attribute_name) != null:
		var new_value = get(attribute_name) + amount
		set(attribute_name, new_value)
		print("增加属性 ", attribute_name, " 值: ", amount, " 当前值: ", new_value)
		emit_signal("attributes_changed", attribute_name, new_value)
		return true
	print("属性不存在: ", attribute_name)
	return false

# 更新属性值
func update_attribute(attribute_name, value):
	if get(attribute_name) != null:
		set(attribute_name, value)
		print("更新属性 ", attribute_name, " 为: ", value)
		emit_signal("attributes_changed", attribute_name, value)
		return true
	print("属性不存在: ", attribute_name)
	return false

# 获取属性值
func get_attribute(attribute_name):
	if get(attribute_name) != null:
		return get(attribute_name)
	print("属性不存在: ", attribute_name)
	return null
