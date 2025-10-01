extends Node

# 任务系统 - 引导玩家体验核心玩法
signal quest_completed(quest_id: String, reward: int)
signal achievement_unlocked(achievement_id: String)
signal daily_quests_reset()

# 每日任务数据
var daily_quests = []
var completed_daily_quests = []

# 成就数据
var achievements = {}
var unlocked_achievements = []

# 任务类型枚举
enum QuestType {
	DAILY,
	ACHIEVEMENT,
	MOD_COLLECTION,
	COMBAT_STAT
}

func _ready():
	print("QuestSystem: _ready() called")
	add_to_group("quest_system")
	initialize_quests()
	initialize_achievements()
	load_progress()

# 初始化每日任务
func initialize_quests():
	daily_quests = [
		{
			"id": "daily_penetration",
			"title": "穿透大师",
			"description": "使用穿透Mod击杀50个敌人",
			"type": QuestType.COMBAT_STAT,
			"target": 50,
			"current": 0,
			"reward_gold": 25,
			"reward_mod_exp": 0.2, # Mod经验+20%
			"mod_type": "penetration"
		},
		{
			"id": "daily_range",
			"title": "范围清场",
			"description": "使用范围Mod击杀100个敌人",
			"type": QuestType.COMBAT_STAT,
			"target": 100,
			"current": 0,
			"reward_gold": 30,
			"reward_mod_exp": 0.2,
			"mod_type": "range"
		},
		{
			"id": "daily_effect",
			"title": "特效触发",
			"description": "触发特效Mod 30次",
			"type": QuestType.COMBAT_STAT,
			"target": 30,
			"current": 0,
			"reward_gold": 20,
			"reward_mod_exp": 0.2,
			"mod_type": "effect"
		}
	]

# 初始化成就系统
func initialize_achievements():
	achievements = {
		"mod_collector": {
			"title": "Mod收藏家",
			"description": "收集10种不同Mod",
			"target": 10,
			"current": 0,
			"reward": "容量上限+2",
			"unlocked": false
		},
		"polarity_expert": {
			"title": "极性专家",
			"description": "完美匹配5次极性",
			"target": 5,
			"current": 0,
			"reward": "极性改造费用-50%",
			"unlocked": false
		},
		"deck_master": {
			"title": "卡组大师",
			"description": "创建10种不同卡组",
			"target": 10,
			"current": 0,
			"reward": "卡组槽位+1",
			"unlocked": false
		},
		"penetration_master": {
			"title": "穿透大师",
			"description": "累计触发100次穿透",
			"target": 100,
			"current": 0,
			"reward": "穿透Mod效果+10%",
			"unlocked": false
		},
		"crit_master": {
			"title": "暴击大师",
			"description": "累计触发80次暴击",
			"target": 80,
			"current": 0,
			"reward": "暴击率+1%",
			"unlocked": false
		}
	}

# 更新任务进度
func update_quest_progress(quest_type: String, amount: int = 1):
	# 更新每日任务
	for quest in daily_quests:
		if quest.mod_type == quest_type and quest.id not in completed_daily_quests:
			quest.current += amount
			if quest.current >= quest.target:
				complete_quest(quest.id)
	
	# 更新成就
	for achievement_id in achievements:
		var achievement = achievements[achievement_id]
		if not achievement.unlocked:
			if achievement_id == "penetration_master" and quest_type == "penetration":
				achievement.current += amount
			elif achievement_id == "crit_master" and quest_type == "crit":
				achievement.current += amount
			
			if achievement.current >= achievement.target:
				unlock_achievement(achievement_id)

# 完成任务
func complete_quest(quest_id: String):
	var quest = get_quest_by_id(quest_id)
	if not quest:
		return
	
	print("任务完成: ", quest.title)
	
	# 发放奖励
	if quest.reward_gold > 0:
		var game_manager = get_node_or_null("/root/Main/GameManager")
		if game_manager:
			game_manager.add_score(quest.reward_gold)
	
	# 应用Mod经验加成
	if quest.reward_mod_exp > 0:
		apply_mod_exp_bonus(quest.mod_type, quest.reward_mod_exp)
	
	# 标记为已完成
	completed_daily_quests.append(quest_id)
	
	# 发出完成信号
	emit_signal("quest_completed", quest_id, quest.reward_gold)

# 解锁成就
func unlock_achievement(achievement_id: String):
	var achievement = achievements[achievement_id]
	if not achievement or achievement.unlocked:
		return
	
	achievement.unlocked = true
	unlocked_achievements.append(achievement_id)
	
	print("成就解锁: ", achievement.title)
	print("奖励: ", achievement.reward)
	
	# 应用成就奖励
	apply_achievement_reward(achievement_id, achievement.reward)
	
	emit_signal("achievement_unlocked", achievement_id)

# 应用Mod经验加成
func apply_mod_exp_bonus(mod_type: String, bonus: float):
	# 这里需要与Mod系统集成
	print("Mod经验加成: ", mod_type, " +", bonus * 100, "%")

# 应用成就奖励
func apply_achievement_reward(achievement_id: String, reward: String):
	match achievement_id:
		"mod_collector":
			# 容量上限+2
			var mod_system = get_node_or_null("/root/ModSystem")
			if mod_system:
				mod_system.add_capacity_bonus(2)
		"polarity_expert":
			# 极性改造费用-50%
			# 这里需要与Mod系统集成
			pass
		"deck_master":
			# 卡组槽位+1
			# 这里需要与Mod系统集成
			pass
		"penetration_master":
			# 穿透Mod效果+10%
			# 这里需要与Mod系统集成
			pass
		"crit_master":
			# 暴击率+1%
			var game_attributes = get_node_or_null("/root/GameAttributes")
			if game_attributes:
				game_attributes.crit_chance += 0.01

# 获取任务信息
func get_quest_by_id(quest_id: String):
	for quest in daily_quests:
		if quest.id == quest_id:
			return quest
	return null

# 获取所有每日任务
func get_daily_quests():
	return daily_quests

# 获取所有成就
func get_achievements():
	return achievements

# 获取已解锁成就
func get_unlocked_achievements():
	return unlocked_achievements

# 重置每日任务
func reset_daily_quests():
	completed_daily_quests.clear()
	for quest in daily_quests:
		quest.current = 0
	emit_signal("daily_quests_reset")

# 保存进度
func save_progress():
	var save_data = {
		"completed_daily_quests": completed_daily_quests,
		"achievements": achievements,
		"unlocked_achievements": unlocked_achievements
	}
	
	var save_file = FileAccess.open("user://quest_progress.save", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()

# 加载进度
func load_progress():
	if not FileAccess.file_exists("user://quest_progress.save"):
		return
	
	var save_file = FileAccess.open("user://quest_progress.save", FileAccess.READ)
	if save_file:
		var json_string = save_file.get_as_text()
		save_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var save_data = json.data
			completed_daily_quests = save_data.get("completed_daily_quests", [])
			achievements = save_data.get("achievements", {})
			unlocked_achievements = save_data.get("unlocked_achievements", [])

# 获取任务完成奖励
func get_quest_reward(quest):
	return quest.reward_gold
