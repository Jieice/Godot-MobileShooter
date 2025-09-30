extends Node

# 天赋系统核心脚本
# 基于文档设计的三系天赋系统（输出、生存、辅助）

signal talent_unlocked(talent_id, level)
# 当消耗点数时发出信号（UI可订阅）
signal talent_point_used(talent_id, points_remaining)

# 天赋定义 - 基于文档的30级系统
var talent_definitions = {
	# 输出系（最多投入10点）
	"attack_range": {
		"name": "攻击范围",
		"tree": "output",
		"max_level": 3,
		"cost_per_level": [1, 1, 1],
		"required_levels": [1, 5, 15],
		"effects": [
			{"attribute": "attack_range", "value": 0.5}, # 1级：+0.5格
			{"attribute": "attack_range", "value": 1.0}, # 2级：+1.0格
			{"attribute": "attack_range", "value": 1.5} # 3级：+1.5格
		],
		"descriptions": ["攻击范围+0.5格", "攻击范围+1格", "攻击范围+1.5格"]
	},
	"penetration_count": {
		"name": "穿透数量",
		"tree": "output",
		"max_level": 3,
		"cost_per_level": [1, 1, 1],
		"required_levels": [1, 5, 15],
		"effects": [
			{"attribute": "penetration_count", "value": 1}, # 1级：+1穿透
			{"attribute": "penetration_count", "value": 2}, # 2级：+2穿透
			{"attribute": "penetration_count", "value": 3} # 3级：+3穿透
		],
		"descriptions": ["穿透数量+1", "穿透数量+2", "穿透数量+3"]
	},
	"crit_chance": {
		"name": "暴击率",
		"tree": "output",
		"max_level": 3,
		"cost_per_level": [1, 1, 1],
		"required_levels": [1, 5, 15],
		"effects": [
			{"attribute": "crit_chance", "value": 0.05}, # 1级：+5%
			{"attribute": "crit_chance", "value": 0.10}, # 2级：+10%
			{"attribute": "crit_chance", "value": 0.15} # 3级：+15%
		],
		"descriptions": ["暴击率+5%", "暴击率+10%", "暴击率+15%"]
	},
	
	# 生存系（最多投入10点）
	"health_boost": {
		"name": "生命值",
		"tree": "survival",
		"max_level": 3,
		"cost_per_level": [1, 1, 1],
		"required_levels": [1, 8, 20],
		"effects": [
			{"attribute": "max_health", "value": 50}, # 1级：+50生命
			{"attribute": "max_health", "value": 100}, # 2级：+100生命
			{"attribute": "max_health", "value": 150} # 3级：+150生命
		],
		"descriptions": ["生命值+50", "生命值+100", "生命值+150"]
	},
	"defense": {
		"name": "减伤",
		"tree": "survival",
		"max_level": 3,
		"cost_per_level": [1, 1, 1],
		"required_levels": [1, 8, 20],
		"effects": [
			{"attribute": "defense", "value": 0.05}, # 1级：+5%减伤
			{"attribute": "defense", "value": 0.10}, # 2级：+10%减伤
			{"attribute": "defense", "value": 0.15} # 3级：+15%减伤
		],
		"descriptions": ["减伤+5%", "减伤+10%", "减伤+15%"]
	},
	"last_stand": {
		"name": "濒死护盾",
		"tree": "survival",
		"max_level": 1,
		"cost_per_level": [3],
		"required_levels": [20],
		"effects": [
			{"attribute": "last_stand_shield_enabled", "value": true,
			 "special": {"threshold": 0.2, "duration": 3.0}} # 20%血量时3秒无敌
		],
		"descriptions": ["生命值低于20%时获得3秒无敌"]
	},
	
	# 辅助系（最多投入10点）
	"elite_priority": {
		"name": "精英优先率",
		"tree": "utility",
		"max_level": 3,
		"cost_per_level": [1, 1, 1],
		"required_levels": [1, 12, 25],
		"effects": [
			{"attribute": "elite_priority_chance", "value": 0.30}, # 1级：+30%
			{"attribute": "elite_priority_chance", "value": 0.50}, # 2级：+50%
			{"attribute": "elite_priority_chance", "value": 0.70} # 3级：+70%
		],
		"descriptions": ["精英优先率+30%", "精英优先率+50%", "精英优先率+70%"]
	},
	"kill_energy": {
		"name": "击杀回能概率",
		"tree": "utility",
		"max_level": 3,
		"cost_per_level": [1, 1, 1],
		"required_levels": [1, 12, 25],
		"effects": [
			{"attribute": "kill_energy_chance", "value": 0.40}, # 1级：+40%
			{"attribute": "kill_energy_chance", "value": 0.60}, # 2级：+60%
			{"attribute": "kill_energy_chance", "value": 0.80} # 3级：+80%
		],
		"descriptions": ["击杀回能概率+40%", "击杀回能概率+60%", "击杀回能概率+80%"]
	},
	"dual_target": {
		"name": "双目标锁定",
		"tree": "utility",
		"max_level": 1,
		"cost_per_level": [3],
		"required_levels": [25],
		"effects": [
			{"attribute": "dual_target_enabled", "value": true}
		],
		"descriptions": ["可同时锁定两个目标"]
	}
}

# 玩家天赋状态
var player_talents = {} # {talent_id: current_level}
var talent_points_used = 0
var max_talent_points = 30 # 30级系统总点数

func _ready():
	add_to_group("talents")
	initialize_talents()

# 初始化天赋状态
func initialize_talents():
	for talent_id in talent_definitions.keys():
		player_talents[talent_id] = 0

# 获取天赋信息
func get_talent_info(talent_id):
	if talent_id in talent_definitions:
		return talent_definitions[talent_id]
	return null

# 获取天赋当前等级
func get_talent_level(talent_id):
	if talent_id in player_talents:
		return player_talents[talent_id]
	return 0

# 检查是否可以升级天赋
func can_upgrade_talent(talent_id, available_points):
	if not talent_id in talent_definitions:
		return {"ok": false, "reason": "天赋不存在"}
	
	var talent = talent_definitions[talent_id]
	var current_level = get_talent_level(talent_id)
	
	# 检查是否已满级
	if current_level >= talent.max_level:
		return {"ok": false, "reason": "天赋已满级"}
	
	# 检查所需等级
	var required_level = talent.required_levels[current_level]
	var player_level = GameAttributes.player_level
	if player_level < required_level:
		return {"ok": false, "reason": "需要等级 " + str(required_level)}
	
	# 检查天赋点数
	var cost = talent.cost_per_level[current_level]
	if available_points < cost:
		return {"ok": false, "reason": "天赋点不足"}
	
	return {"ok": true, "reason": ""}

# 升级天赋
func upgrade_talent(talent_id, available_points):
	var check = can_upgrade_talent(talent_id, available_points)
	if not check.ok:
		print("无法升级天赋 ", talent_id, ": ", check.reason)
		return false
	
	var talent = talent_definitions[talent_id]
	var current_level = get_talent_level(talent_id)
	var cost = talent.cost_per_level[current_level]
	
	# 升级天赋
	player_talents[talent_id] += 1
	talent_points_used += cost
	
	# 应用天赋效果
	apply_talent_effect(talent_id, current_level + 1)
	
	# 发送信号
	emit_signal("talent_unlocked", talent_id, current_level + 1)
	emit_signal("talent_point_used", talent_id, get_remaining_talent_points())
	
	print("升级天赋: ", talent.name, " 到等级 ", current_level + 1)
	return true

# 应用天赋效果
func apply_talent_effect(talent_id, level):
	var talent = talent_definitions[talent_id]
	if not talent or level > talent.max_level:
		return
	
	var effect = talent.effects[level - 1]
	var attribute = effect["attribute"]
	var value = effect["value"]
	
	# 应用基础属性效果
	if effect.has("special"):
		# 特殊效果处理
		var special = effect["special"]
		if attribute == "last_stand_shield_enabled":
			GameAttributes.last_stand_shield_enabled = value
			GameAttributes.last_stand_shield_threshold = special.threshold
			GameAttributes.last_stand_shield_duration = special.duration
		elif attribute == "dual_target_enabled":
			GameAttributes.dual_target_enabled = value
	else:
		# 普通属性效果
		var current_value = GameAttributes.get(attribute)
		if current_value != null:
			if current_value is bool:
				GameAttributes.set(attribute, value)
			else:
				GameAttributes.set(attribute, current_value + value)
		else:
			print("警告: 属性 ", attribute, " 不存在于 GameAttributes")

# 获取已使用的天赋点数
func get_used_talent_points():
	return talent_points_used

# 获取剩余天赋点数
func get_remaining_talent_points():
	var total_points = GameAttributes.player_level * 1 # 每级1点
	return total_points - talent_points_used

# 重置天赋（用于测试）
func reset_talents():
	player_talents.clear()
	initialize_talents()
	talent_points_used = 0
	print("天赋已重置")

# 获取天赋树信息
func get_talent_tree_info():
	var trees = {
		"output": {"name": "输出系", "talents": [], "points_used": 0},
		"survival": {"name": "生存系", "talents": [], "points_used": 0},
		"utility": {"name": "辅助系", "talents": [], "points_used": 0}
	}
	
	for talent_id in talent_definitions.keys():
		var talent = talent_definitions[talent_id]
		var tree = talent.tree
		var current_level = get_talent_level(talent_id)
		
		trees[tree].talents.append({
			"id": talent_id,
			"name": talent.name,
			"level": current_level,
			"max_level": talent.max_level,
			"can_upgrade": can_upgrade_talent(talent_id, get_remaining_talent_points()).ok,
			"cost": talent.cost_per_level[current_level] if current_level < talent.max_level else 0,
			"required_level": talent.required_levels[current_level] if current_level < talent.max_level else 0
		})
		
		# 计算该系已用点数
		for i in range(current_level):
			trees[tree].points_used += talent.cost_per_level[i]
	
	return trees
