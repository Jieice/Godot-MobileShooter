extends Node

# 存档系统 - 使用加密的ConfigFile
# 支持玩家进度、MOD收集、设置等数据保存

signal save_completed
signal load_completed
signal save_failed(error_message)
signal load_failed(error_message)
signal delete_completed
signal delete_failed(error_message)

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
		"shield_value": 0,
		"elite_damage_bonus": 0.0,
		"chain_reaction_enabled": false,
		"life_siphon_enabled": false
	},
	"talents": {
		"output_points_used": 0,
		"survival_points_used": 0,
		"utility_points_used": 0,
		"unlocked_talents": []
	},
	"mod_system": {
		"core_module_type": 0, # CoreModuleType.BASIC_TURRET
		"equipped_mods": {},
		"mod_inventory": [],
		"mod_definitions": {} # 保存MOD定义，用于版本升级
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
	# 检测移动平台
	is_mobile_platform = OS.has_feature("mobile")
	print("当前平台: ", "移动平台" if is_mobile_platform else "桌面平台")
	
	# 连接MOD系统信号
	if ModSystem:
		ModSystem.connect("mod_equipped", Callable(self, "_on_mod_equipped"))
		ModSystem.connect("mod_unequipped", Callable(self, "_on_mod_unequipped"))

# 保存游戏数据
func save_game():
	var config = ConfigFile.new()
	
	# 收集当前游戏数据
	var save_data = collect_current_data()
	
	print("保存数据结构: ", save_data)
	
	# 将数据写入ConfigFile
	for section in save_data:
		print("处理节: ", section, " 类型: ", typeof(save_data[section]))
		if typeof(save_data[section]) == TYPE_DICTIONARY:
			# 如果是字典，遍历其键值对
			for key in save_data[section]:
				print("  保存键: ", key, " 值: ", save_data[section][key])
				config.set_value(section, key, save_data[section][key])
		else:
			# 如果不是字典，直接保存值
			print("  保存到general节: ", section, " 值: ", save_data[section])
			config.set_value("general", section, save_data[section])
	
	# 保存到文件（带加密）
	var error = config.save_encrypted_pass(SAVE_FILE_PATH, ENCRYPTION_KEY)
	
	if error == OK:
		print("游戏数据保存成功")
		
		# 创建备份
		create_backup()
		
		# 移动平台额外处理
		if is_mobile_platform:
			_handle_mobile_save()
		
		# 确保文件写入完成后再发出信号
		await get_tree().process_frame
		print("文件写入完成，发出保存完成信号")
		emit_signal("save_completed")
	else:
		print("游戏数据保存失败: ", error)
		emit_signal("save_failed", "保存失败: " + str(error))

# 加载游戏数据
func load_game():
	var config = ConfigFile.new()
	
	# 尝试加载主存档文件
	var error = config.load_encrypted_pass(SAVE_FILE_PATH, ENCRYPTION_KEY)
	
	# 如果主存档失败，尝试加载备份
	if error != OK:
		print("主存档加载失败，尝试加载备份: ", error)
		error = config.load_encrypted_pass(BACKUP_FILE_PATH, ENCRYPTION_KEY)
		
		if error != OK:
			print("备份存档也加载失败，使用默认数据: ", error)
			emit_signal("load_failed", "存档文件损坏或不存在")
			return false
	
	# 解析存档数据
	var save_data = parse_save_data(config)
	
	# 应用存档数据到游戏
	apply_save_data(save_data)
	
	print("游戏数据加载成功")
	emit_signal("load_completed")
	return true

# 收集当前游戏数据
func collect_current_data():
	var save_data = default_save_data.duplicate(true)
	
	# 获取GameManager引用
	var game_manager = get_node_or_null("/root/Main/GameManager")
	
	# 收集玩家数据
	var player = get_node_or_null("/root/Main/Player")
	if player:
		save_data.player.level = GameAttributes.player_level
		save_data.player.experience = GameAttributes.player_experience
		save_data.player.experience_to_next = GameAttributes.experience_required
		save_data.player.health = player.health
		save_data.player.max_health = player.max_health
		# 同步GameManager的分数到GameAttributes
		if game_manager:
			GameAttributes.score = game_manager.score
		
		save_data.player.score = GameAttributes.score
		save_data.player.talent_points = GameAttributes.talent_points
	
	# 收集游戏属性
	for attr in save_data.game_attributes:
		if attr in GameAttributes:
			save_data.game_attributes[attr] = GameAttributes.get(attr)
	
	# 收集天赋数据
	var talents = get_node_or_null("/root/Main/Talents")
	if talents and talents.has_method("get_talent_tree_info"):
		var talent_info = talents.get_talent_tree_info()
		save_data.talents.output_points_used = talent_info.output.points_used
		save_data.talents.survival_points_used = talent_info.survival.points_used
		save_data.talents.utility_points_used = talent_info.utility.points_used
		
		# 收集已解锁的天赋
		var unlocked_talents = []
		for tree_key in ["output", "survival", "utility"]:
			var tree_data = talent_info[tree_key]
			for talent in tree_data.talents:
				if talent.level > 0:
					unlocked_talents.append(talent.id)
		save_data.talents.unlocked_talents = unlocked_talents
	
	# 收集MOD系统数据
	if ModSystem:
		save_data.mod_system.core_module_type = ModSystem.player_core_module.type
		save_data.mod_system.equipped_mods = ModSystem.player_core_module.equipped_mods.duplicate()
		save_data.mod_system.mod_inventory = ModSystem.mod_inventory.duplicate()
	
	# 收集游戏进度
	if game_manager:
		save_data.game_progress.current_level = game_manager.current_level
		save_data.game_progress.total_score = game_manager.score
	
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
	# 应用玩家数据
	GameAttributes.player_level = save_data.player.level
	GameAttributes.player_experience = save_data.player.experience
	GameAttributes.experience_required = save_data.player.experience_to_next
	GameAttributes.health = save_data.player.health
	GameAttributes.max_health = save_data.player.max_health
	GameAttributes.score = save_data.player.score
	GameAttributes.talent_points = save_data.player.talent_points
	
	# 同步GameManager的分数
	var gm = get_node("/root/Main/GameManager")
	if gm:
		gm.score = GameAttributes.score
	
	# 应用游戏属性
	for attr in save_data.game_attributes:
		if attr in GameAttributes:
			GameAttributes.set(attr, save_data.game_attributes[attr])
	
	# 应用天赋数据
	var talents = get_node_or_null("/root/Main/Talents")
	if talents and talents.has_method("load_talent_data"):
		talents.load_talent_data(save_data.talents)
	
	# 应用MOD系统数据
	if ModSystem:
		ModSystem.load_mod_data(save_data.mod_system)
	
	# 应用游戏进度
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager:
		game_manager.current_level = save_data.game_progress.current_level
		game_manager.score = save_data.game_progress.total_score
	
	# 更新玩家血量
	var player = get_node_or_null("/root/Main/Player")
	if player:
		player.health = GameAttributes.health
		player.max_health = GameAttributes.max_health
		print("更新玩家血量: ", player.health, "/", player.max_health)
	
	# 通知UI更新
	var ui_manager = get_node_or_null("/root/Main/UI")
	if ui_manager:
		ui_manager.update_player_stats()
		ui_manager.update_health_display()
		# 强制更新所有UI元素
		ui_manager.update_mod_inventory()
		ui_manager.update_mod_slots()
		ui_manager.update_capacity_display()
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
		print("存档已删除")
		emit_signal("delete_completed")
	else:
		print("没有存档可删除")
		emit_signal("delete_failed", "没有存档可删除")

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

# 移动平台特殊处理
func _handle_mobile_save():
	# 在移动平台上，可以添加额外的处理逻辑
	# 比如：云存档同步、数据压缩、权限检查等
	print("移动平台存档处理完成")
	
	# 示例：检查存储空间
	_check_storage_space()
	
	# 示例：触发云存档同步（如果启用）
	if has_node("/root/CloudSaveSystem"):
		get_node("/root/CloudSaveSystem").save_to_cloud()

# 检查存储空间
func _check_storage_space():
	# 检查可用存储空间
	var available_space = OS.get_static_memory_usage()
	print("当前内存使用: ", available_space, " bytes")
	
	# 如果存储空间不足，可以清理旧数据或压缩存档
	if available_space > 100 * 1024 * 1024: # 100MB
		print("警告：内存使用过高")

# 移动平台存档路径获取
func get_mobile_save_path() -> String:
	if OS.has_feature("android"):
		return "/storage/emulated/0/Android/data/com.yourcompany.mobileShooter/files/"
	elif OS.has_feature("ios"):
		return OS.get_user_data_dir()
	else:
		return OS.get_user_data_dir()

# 检查移动平台权限
func check_mobile_permissions() -> bool:
	if not is_mobile_platform:
		return true
	
	# Android权限检查
	if OS.has_feature("android"):
		# 这里需要调用Android原生代码检查权限
		# 示例：检查存储权限
		return true
	
	# iOS权限检查
	if OS.has_feature("ios"):
		# iOS通常不需要额外权限
		return true
	
	return false

# MOD系统信号处理
func _on_mod_equipped(_mod_id, _slot_index):
	# MOD装备时自动保存
	save_game()

func _on_mod_unequipped(_mod_id, _slot_index):
	# MOD卸下时自动保存
	save_game()
