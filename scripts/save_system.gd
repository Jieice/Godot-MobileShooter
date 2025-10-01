extends Node

# 存档系统 - 使用加密的ConfigFile
# 支持玩家进度、MOD收集、设置等数据保存

# signal save_completed # 已移除，改为自动存档，无需UI反馈
# signal load_completed # 已移除，改为自动存档，无需UI反馈
# signal save_failed(error_message) # 已移除
# signal load_failed(error_message) # 已移除
# signal delete_completed # 已移除
# signal delete_failed(error_message) # 已移除

# 存档文件路径
const SAVE_FILE_PATH = "user://save_data.cfg"
const BACKUP_FILE_PATH = "user://save_data_backup.cfg"

# 移动平台特殊处理
var is_mobile_platform = false

# 加密密钥（实际项目中应该使用更复杂的密钥）
const ENCRYPTION_KEY = "MobileShooter2024SaveKey"

# 存档版本（用于版本升级）
const SAVE_VERSION = "1.0"

# 默认存档数据
var default_save_data = {
	"version": SAVE_VERSION,
	"player": {
		"level": 1,
		"experience": 0,
		"experience_to_next": 100,
		"health": 80,
		"max_health": 80,
		"score": 0,
		"talent_points": 0
	},
	"game_attributes": {
		"bullet_damage": 10,
		"crit_chance": 0.1,
		"double_shot_chance": 0.0,
		"triple_shot_chance": 0.0,
		"attack_speed": 1.0,
		"attack_range": 1.0,
		"penetration_count": 0,
		"bleed_chance": 0.0,
		"bleed_damage_per_second": 5.0,
		"bleed_duration": 3.0,
		"fission_chance": 0.0,
		"defense": 0.0,
		"dodge_chance": 0.0,
		"crush_chance": 0.0,
		"crush_boss_bonus": 0.0,
		"last_stand_shield_enabled": false,
		"last_stand_shield_threshold": 0.2,
		"last_stand_shield_duration": 3.0,
		"elite_priority_chance": 0.0,
		"kill_energy_chance": 0.0,
		"dual_target_enabled": false,
	},
	"talents": {
		"unlocked_talents_with_levels": [] # 存储已解锁天赋及其等级的列表
	},
	"game_progress": {
		"current_level": 1,
		"highest_level_reached": 1,
		"total_score": 0,
		"total_enemies_killed": 0,
		"total_play_time": 0.0
	},
	"settings": {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 1.0,
		"auto_fire": true,
		"show_damage_numbers": true
	}
}

func _ready():
	print("SaveSystem: _ready() called")
	add_to_group("save_system")
	# 检测移动平台
	is_mobile_platform = OS.has_feature("mobile")
	print("当前平台: ", "移动平台" if is_mobile_platform else "桌面平台")
	
	
	# 游戏启动时自动加载存档
	load_game()

# 保存游戏数据
func save_game():
	var config = ConfigFile.new()
	
	# 收集当前游戏数据
	var save_data = collect_current_data()
	
	# 将数据写入ConfigFile
	for section in save_data:
		if typeof(save_data[section]) == TYPE_DICTIONARY:
			for key in save_data[section]:
				config.set_value(section, key, save_data[section][key])
		else:
			config.set_value("general", section, save_data[section])
	
	# 保存到文件（带加密）
	var error = config.save_encrypted_pass(SAVE_FILE_PATH, ENCRYPTION_KEY)
	
	if error == OK:
		print("游戏数据保存成功")
		
		# 创建备份
		create_backup()
		
		# 移动平台额外处理 (如果需要，否则移除)
		# if is_mobile_platform:
		# 	_handle_mobile_save()
		
		# 确保文件写入完成后再发出信号 (自动存档无需UI反馈信号)
		await get_tree().process_frame
	else:
		print("游戏数据保存失败: ", error)
		# print("具体的保存错误代码: ", error_string(error)) # 已移除
		# emit_signal("save_failed", "保存失败: " + error_string(error)) # 已移除

# 加载游戏数据
func load_game():
	print("SaveSystem: load_game() called")
	var config = ConfigFile.new()
	
	# 尝试加载主存档文件
	var error = config.load_encrypted_pass(SAVE_FILE_PATH, ENCRYPTION_KEY)
	
	# 如果主存档失败，尝试加载备份
	if error != OK:
		print("SaveSystem: 主存档加载失败，尝试加载备份: ", error)
		error = config.load_encrypted_pass(BACKUP_FILE_PATH, ENCRYPTION_KEY)
		
		if error != OK:
			print("SaveSystem: 备份存档也加载失败，使用默认数据: ", error)
			return false
	
	# 解析存档数据
	var save_data = parse_save_data(config)
	print("SaveSystem: 解析到的存档数据: ", save_data)
	
	# 应用存档数据到游戏
	apply_save_data(save_data)
	
	print("SaveSystem: 游戏数据加载成功")
	# emit_signal("load_completed") # 已移除
	

	return true

# 收集当前游戏数据
func collect_current_data():
	var save_data = default_save_data.duplicate(true)
	
	var game_manager = get_node_or_null("/root/Main/GameManager")
	var level_manager = get_node_or_null("/root/LevelManager")
	var talents = get_node_or_null("/root/Talents")

	# Collect player attributes from GameAttributes
	save_data.player.health = GameAttributes.health
	save_data.player.max_health = GameAttributes.max_health
	save_data.player.score = GameAttributes.score # This will be updated by game_manager later if present

	# Collect LevelManager data
	if level_manager:
		save_data.player.level = level_manager.player_level
		save_data.player.experience = level_manager.player_exp
		save_data.player.experience_to_next = level_manager.exp_to_next_level
		save_data.player.talent_points = level_manager.talent_points
		save_data.player.total_talent_points = level_manager.total_talent_points
		save_data.game_progress.current_level = level_manager.current_level
		if level_manager.current_level > save_data.game_progress.highest_level_reached:
			save_data.game_progress.highest_level_reached = level_manager.current_level

	# Collect other GameAttributes
	for attr in save_data.game_attributes:
		if attr in GameAttributes:
			save_data.game_attributes[attr] = GameAttributes.get(attr)

	# Collect Talent data
	if talents:
		var unlocked_talents_with_levels = []
		for talent_id in talents.player_talents.keys():
			var level = talents.player_talents[talent_id]
			if level > 0:
				unlocked_talents_with_levels.append({"id": talent_id, "level": level})
		save_data.talents.unlocked_talents_with_levels = unlocked_talents_with_levels

	# Collect GameManager data
	if game_manager:
		save_data.game_progress.total_score = game_manager.score
		# Ensure GameAttributes.score is updated from game_manager.score
		GameAttributes.score = game_manager.score


	return save_data

# 解析存档数据
func parse_save_data(config: ConfigFile):
	var save_data = default_save_data.duplicate(true)
	
	# 从ConfigFile中读取数据
	for section in save_data:
		if typeof(save_data[section]) == TYPE_DICTIONARY:
			# 如果是字典，遍历其键值对
			for key in save_data[section]:
				if config.has_section_key(section, key):
					save_data[section][key] = config.get_value(section, key, save_data[section][key])
		else:
			# 如果不是字典，从general节读取
			if config.has_section_key("general", section):
				save_data[section] = config.get_value("general", section, save_data[section])
	
	return save_data

# 应用存档数据到游戏
func apply_save_data(save_data: Dictionary):
	# 应用到LevelManager
	var level_manager = get_node("/root/LevelManager")
	if level_manager:
		level_manager.player_level = save_data.player.level
		level_manager.player_exp = save_data.player.experience
		level_manager.exp_to_next_level = save_data.player.experience_to_next
		level_manager.talent_points = save_data.player.talent_points
		level_manager.current_level = save_data.game_progress.current_level
	
	# 应用
	
	# 同步GameManager的分数
	var gm = get_node("/root/Main/GameManager")
	if gm:
		gm.score = GameAttributes.score
	
	# 应用游戏属性
	for attr in save_data.game_attributes:
		if attr in GameAttributes:
			GameAttributes.set(attr, save_data.game_attributes[attr])
	
	# 应用天赋数据
	var talents = get_node_or_null("/root/Talents")
	if talents and talents.has_method("load_talent_data"):
		talents.load_talent_data(save_data.talents)
	
	
	# 应用游戏进度
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager:
		# game_manager.current_level = save_data.game_progress.current_level # 移除此行
		game_manager.score = save_data.game_progress.total_score # 保持此行
	
	# 将关卡信息应用到LevelManager
	level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		level_manager.current_level = save_data.game_progress.current_level
		print("SaveSystem: 已将存档的关卡 \"" + str(save_data.game_progress.current_level) + "\" 应用到LevelManager")
	
	# 更新玩家血量
	var player = get_node_or_null("/root/Main/Player")
	if player:
		player.health = GameAttributes.health
		player.max_health = GameAttributes.max_health
		print("更新玩家血量: ", player.health, "/", player.max_health)
	
	# 通知UI更新
	var ui_manager = get_node_or_null("/root/Main/HUD")
	if ui_manager:
		ui_manager.update_health_display()
		print("UI更新完成")

# 创建备份存档
func create_backup():
	var config = ConfigFile.new()
	var error = config.load_encrypted_pass(SAVE_FILE_PATH, ENCRYPTION_KEY)
	
	if error == OK:
		config.save_encrypted_pass(BACKUP_FILE_PATH, ENCRYPTION_KEY)
		print("备份存档创建成功")

# 检查存档是否存在
func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

# 删除存档
func delete_save():
	if save_exists():
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		DirAccess.remove_absolute(BACKUP_FILE_PATH) # 同时删除备份
		print("存档已删除")
		# emit_signal("delete_completed") # 已移除
	else:
		print("没有存档可删除")
		# emit_signal("delete_failed", "没有存档可删除") # 已移除

# 获取存档信息
func get_save_info() -> Dictionary:
	# 减少调试信息输出，避免日志过多
	if not save_exists():
		return {}
	
	var config = ConfigFile.new()
	var error = config.load_encrypted_pass(SAVE_FILE_PATH, ENCRYPTION_KEY)
	
	if error != OK:
		print("存档加载失败: ", error)
		return {}
	
	var info = {
		"version": config.get_value("general", "version", "未知"),
		"player_level": config.get_value("player", "level", 1),
		"total_score": config.get_value("game_progress", "total_score", 0),
		"highest_level": config.get_value("game_progress", "highest_level_reached", 1)
	}
	
	# 验证信息有效性
	if info.player_level <= 0 or info.total_score < 0 or info.highest_level <= 0:
		print("存档信息无效: ", info)
		return {}
	
	return info

# 移动平台特殊处理 - 此函数已废弃
func _handle_mobile_save():
	pass # 逻辑已移除

# 检查存储空间 - 此函数已废弃
func _check_storage_space():
	pass # 逻辑已移除

# 移动平台存档路径获取 - 此函数已废弃
func get_mobile_save_path() -> String:
	return "" # 逻辑已移除

# 检查移动平台权限 - 此函数已废弃
func check_mobile_permissions() -> bool:
	return true # 逻辑已移除
