extends Node

# 任务和成就系统
# 管理每日任务、成就和奖励

signal quest_completed(quest_id, reward)
signal achievement_unlocked(achievement_id, reward)
signal daily_quests_reset

# 任务类型
enum QuestType {
	DAILY, # 每日任务
	ACHIEVEMENT # 成就
}

# 任务状态
enum QuestStatus {
	LOCKED, # 未解锁
	ACTIVE, # 进行中
	COMPLETED, # 已完成
	CLAIMED # 已领取
}

# 任务数据结构
class QuestData:
	var id: String
	var title: String
	var description: String
	var quest_type: QuestType
	var status: QuestStatus = QuestStatus.LOCKED
	var progress: int = 0
	var target: int = 1
	var reward_type: String = "gold" # gold, diamond, mod, buff
	var reward_value: int = 0
	var reward_item: String = ""
	var unlock_condition: Dictionary = {}
	var is_repeatable: bool = false
	var created_time: int = 0

# 任务数据库
var quest_database: Dictionary = {}
var active_quests: Array[String] = []
var completed_achievements: Array[String] = []

# 每日任务重置时间
var last_reset_time: int = 0

func _ready():
	add_to_group("quest_system")
	initialize_quest_database()
	load_quest_progress()
	# 延迟检查每日重置，避免启动时的时间问题
	call_deferred("check_daily_reset")

# 初始化任务数据库
func initialize_quest_database():
	# 每日任务
	create_daily_quest("daily_combo_15", "连击大师", "触发15次连击", 15, "gold", 25)
	create_daily_quest("daily_crit_10", "暴击专家", "触发10次暴击", 10, "diamond", 5)
	create_daily_quest("daily_kill_50", "杀戮机器", "击杀50个敌人", 50, "gold", 30)
	create_daily_quest("daily_survive_5", "生存专家", "存活5分钟", 5, "mod", 0, "high_speed_shooting")
	create_daily_quest("daily_level_3", "升级达人", "提升3个等级", 3, "gold", 40)
	
	# 成就系统
	create_achievement("ach_combo_100", "连击之王", "累计触发100次连击", 100, "permanent", 2, "combo_chance")
	create_achievement("ach_crit_80", "暴击大师", "累计触发80次暴击", 80, "permanent", 1, "crit_chance")
	create_achievement("ach_kill_1000", "千人斩", "累计击杀1000个敌人", 1000, "gold", 200)
	create_achievement("ach_survive_30", "生存传奇", "单次存活30分钟", 30, "mod", 0, "chain_reaction")
	create_achievement("ach_level_30", "满级玩家", "达到30级", 30, "diamond", 50)

# 创建每日任务
func create_daily_quest(id: String, title: String, description: String, target: int, reward_type: String, reward_value: int, reward_item: String = ""):
	var quest = QuestData.new()
	quest.id = id
	quest.title = title
	quest.description = description
	quest.quest_type = QuestType.DAILY
	quest.target = target
	quest.reward_type = reward_type
	quest.reward_value = reward_value
	quest.reward_item = reward_item
	quest.is_repeatable = true
	quest.created_time = Time.get_unix_time_from_system()
	
	quest_database[id] = quest
	active_quests.append(id)

# 创建成就
func create_achievement(id: String, title: String, description: String, target: int, reward_type: String, reward_value: int, reward_item: String = ""):
	var quest = QuestData.new()
	quest.id = id
	quest.title = title
	quest.description = description
	quest.quest_type = QuestType.ACHIEVEMENT
	quest.target = target
	quest.reward_type = reward_type
	quest.reward_value = reward_value
	quest.reward_item = reward_item
	quest.is_repeatable = false
	quest.status = QuestStatus.ACTIVE
	
	quest_database[id] = quest

# 更新任务进度
func update_quest_progress(quest_type: String, amount: int = 1):
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		if quest.status != QuestStatus.ACTIVE:
			continue
		
		# 检查任务类型匹配
		var matches = false
		match quest_type:
			"combo":
				matches = quest.id.contains("combo")
			"crit":
				matches = quest.id.contains("crit")
			"kill":
				matches = quest.id.contains("kill")
			"survive":
				matches = quest.id.contains("survive")
			"level":
				matches = quest.id.contains("level")
		
		if matches:
			quest.progress += amount
			quest.progress = min(quest.progress, quest.target)
			
			# 检查是否完成
			if quest.progress >= quest.target:
				complete_quest(quest_id)

# 完成任务
func complete_quest(quest_id: String):
	if not quest_id in quest_database:
		return
	
	var quest = quest_database[quest_id]
	quest.status = QuestStatus.COMPLETED
	
	# 发出完成信号
	emit_signal("quest_completed", quest_id, get_quest_reward(quest))
	
	# 如果是成就，添加到已完成列表
	if quest.quest_type == QuestType.ACHIEVEMENT:
		completed_achievements.append(quest_id)
		emit_signal("achievement_unlocked", quest_id, get_quest_reward(quest))
	
	print("任务完成: ", quest.title)

# 领取任务奖励
func claim_quest_reward(quest_id: String) -> bool:
	if not quest_id in quest_database:
		return false
	
	var quest = quest_database[quest_id]
	if quest.status != QuestStatus.COMPLETED:
		return false
	
	# 发放奖励
	give_quest_reward(quest)
	
	# 更新状态
	quest.status = QuestStatus.CLAIMED
	
	# 如果是每日任务，重置进度
	if quest.quest_type == QuestType.DAILY and quest.is_repeatable:
		quest.progress = 0
		quest.status = QuestStatus.ACTIVE
	
	return true

# 获取任务奖励
func get_quest_reward(quest: QuestData) -> Dictionary:
	return {
		"type": quest.reward_type,
		"value": quest.reward_value,
		"item": quest.reward_item
	}

# 发放任务奖励
func give_quest_reward(quest: QuestData):
	match quest.reward_type:
		"gold":
			# 通过游戏管理器添加金币
			var game_manager = get_node_or_null("/root/Main/GameManager")
			if game_manager:
				game_manager.add_score(quest.reward_value)
			print("获得金币: ", quest.reward_value)
		"diamond":
			GameAttributes.diamonds += quest.reward_value
			print("获得钻石: ", quest.reward_value)
		"mod":
			if quest.reward_item != "":
				ModSystem.add_mod_to_inventory(quest.reward_item)
				print("获得MOD: ", quest.reward_item)
		"permanent":
			# 永久属性提升
			apply_permanent_bonus(quest.reward_item, quest.reward_value)
			print("永久属性提升: ", quest.reward_item, " +", quest.reward_value, "%")

# 应用永久属性加成
func apply_permanent_bonus(attribute: String, value: int):
	match attribute:
		"combo_chance":
			GameAttributes.double_shot_chance += value * 0.01
			GameAttributes.triple_shot_chance += value * 0.01
		"crit_chance":
			GameAttributes.crit_chance += value * 0.01

# 检查每日任务重置
func check_daily_reset():
	var current_time = Time.get_unix_time_from_system()
	var current_datetime = Time.get_datetime_dict_from_unix_time(current_time)
	var last_datetime = Time.get_datetime_dict_from_unix_time(last_reset_time)
	
	if current_datetime["day"] != last_datetime["day"]:
		reset_daily_quests()
		last_reset_time = int(current_time)

# 重置每日任务
func reset_daily_quests():
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		if quest.quest_type == QuestType.DAILY:
			quest.progress = 0
			quest.status = QuestStatus.ACTIVE
	
	emit_signal("daily_quests_reset")
	print("每日任务已重置")

# 获取活跃任务列表
func get_active_quests() -> Array:
	var active_list = []
	for quest_id in active_quests:
		if quest_id in quest_database:
			var quest = quest_database[quest_id]
			if quest.status == QuestStatus.ACTIVE or quest.status == QuestStatus.COMPLETED:
				active_list.append(quest)
	return active_list

# 获取已完成任务列表
func get_completed_quests() -> Array:
	var completed_list = []
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		if quest.status == QuestStatus.COMPLETED or quest.status == QuestStatus.CLAIMED:
			completed_list.append(quest)
	return completed_list

# 获取成就列表
func get_achievements() -> Array:
	var achievement_list = []
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		if quest.quest_type == QuestType.ACHIEVEMENT:
			achievement_list.append(quest)
	return achievement_list

# 保存任务进度
func save_quest_progress():
	var save_data = {
		"active_quests": active_quests,
		"completed_achievements": completed_achievements,
		"last_reset_time": last_reset_time,
		"quest_progress": {}
	}
	
	# 保存每个任务的进度
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		save_data.quest_progress[quest_id] = {
			"progress": quest.progress,
			"status": quest.status
		}
	
	# 保存到文件
	var file = FileAccess.open("user://quest_progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

# 加载任务进度
func load_quest_progress():
	var file = FileAccess.open("user://quest_progress.json", FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return
	
	var save_data = json.data
	active_quests = save_data.get("active_quests", [])
	completed_achievements = save_data.get("completed_achievements", [])
	last_reset_time = save_data.get("last_reset_time", 0)
	
	# 恢复任务进度
	var quest_progress = save_data.get("quest_progress", {})
	for quest_id in quest_progress:
		if quest_id in quest_database:
			var quest = quest_database[quest_id]
			var progress_data = quest_progress[quest_id]
			quest.progress = progress_data.get("progress", 0)
			quest.status = progress_data.get("status", QuestStatus.ACTIVE)

# 获取任务统计信息
func get_quest_statistics() -> Dictionary:
	var stats = {
		"total_quests": quest_database.size(),
		"active_quests": 0,
		"completed_quests": 0,
		"total_achievements": 0,
		"unlocked_achievements": completed_achievements.size()
	}
	
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		if quest.status == QuestStatus.ACTIVE:
			stats.active_quests += 1
		elif quest.status == QuestStatus.COMPLETED or quest.status == QuestStatus.CLAIMED:
			stats.completed_quests += 1
		
		if quest.quest_type == QuestType.ACHIEVEMENT:
			stats.total_achievements += 1
	
	return stats
