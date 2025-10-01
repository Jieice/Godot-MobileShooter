extends CanvasLayer

# UI管理器 - 负责管理所有游戏UI元素
signal ui_ready

var _player: CharacterBody2D
var _game_manager: Node

func _ready():
	print("UIManager: _ready() called")
	add_to_group("ui_manager")
	print("UI管理器初始化开始")
	
	# 获取玩家引用
	_player = get_node("../Player")
	if not _player:
		print("UIManager: 警告: 无法找到Player节点")
		return
	
	# 获取游戏管理器引用
	_game_manager = get_node("../GameManager")
	if not _game_manager:
		print("UIManager: 警告: 无法找到GameManager节点")
		return
	
	# 连接信号
	_connect_signals()
	
	# 初始化UI
	# _initialize_ui() # UI初始化现在由各个Panel自行管理，UIManager不再负责全部初始化
	
	# 启动定期UI更新
	_start_ui_update_timer()
	
	# 确保GameOverPanel在启动时隐藏
	var game_over_panel = get_node_or_null("GameOverPanel")
	if game_over_panel:
		game_over_panel.visible = false
		print("UIManager: GameOverPanel set to visible = false in _ready()")
	else:
		print("UIManager: GameOverPanel not found in _ready()")
	
	# 检查UI节点是否存在（只在初始化时打印一次）
	print("UIManager: UI管理器初始化完成")
	print("UIManager:   - InGameLevelInfo/InGameLevel: ", has_node("InGameLevelInfo/InGameLevel"))
	print("UIManager:   - InGameLevelInfo/ExpLabel: ", has_node("InGameLevelInfo/ExpLabel"))
	print("UIManager:   - InGameLevelInfo/ExpBar: ", has_node("InGameLevelInfo/ExpBar"))
	print("UIManager:   - PlayerLevel: ", has_node("PlayerLevel"))
	print("UIManager:   - ScoreLabel: ", has_node("ScoreLabel"))
	# 初始化钻石显示
	_on_diamonds_changed(GameAttributes.diamonds)
	# 初始化金币显示
	_on_score_updated(_game_manager.score)
	
	# 初始UI更新
	update_player_level()
	update_exp_display()
	update_level_display()
	emit_signal("ui_ready")

func _connect_signals():
	# 连接玩家信号
	if _player.has_signal("player_damaged"):
		_player.connect("player_damaged", Callable(self, "_on_player_damaged"))
	
	# 连接游戏管理器信号
	if _game_manager.has_signal("score_updated"):
		_game_manager.connect("score_updated", Callable(self, "_on_score_updated"))
		if _game_manager.has_signal("game_over_triggered"):
			_game_manager.connect("game_over_triggered", Callable(self, "_on_game_over_triggered"))
		if _game_manager.has_signal("game_restarted"):
			_game_manager.connect("game_restarted", Callable(self, "_on_game_restarted"))
	
	# 连接游戏属性信号
	if GameAttributes.has_signal("diamonds_changed"):
		GameAttributes.connect("diamonds_changed", Callable(self, "_on_diamonds_changed"))
	
	# 连接任务系统信号
	var quest_system = get_node("/root/QuestSystem")
	if quest_system:
		quest_system.connect("quest_completed", Callable(self, "_on_quest_completed"))
		quest_system.connect("achievement_unlocked", Callable(self, "_on_achievement_unlocked"))
		quest_system.connect("daily_quests_reset", Callable(self, "_on_daily_quests_reset"))

	# 连接GameAttributes信号
	if GameAttributes.has_signal("attributes_changed"):
		GameAttributes.connect("attributes_changed", Callable(self, "_on_game_attribute_changed"))

	# 连接LevelManager信号
	var level_manager = get_node("/root/LevelManager")
	if level_manager:
		if level_manager.has_signal("player_level_up"):
			level_manager.connect("player_level_up", Callable(self, "_on_player_level_up"))
		if level_manager.has_signal("talent_points_changed"):
			level_manager.connect("talent_points_changed", Callable(self, "_on_talent_points_changed"))
		if level_manager.has_signal("level_started"):
			level_manager.connect("level_started", Callable(self, "_on_level_started"))
		if level_manager.has_signal("level_progress_updated"):
			level_manager.connect("level_progress_updated", Callable(self, "_on_level_progress_updated"))


func _initialize_ui():
	# 初始化UI
	var gm = get_node("../GameManager")
	if gm:
		$ScoreLabel.text = "金币: " + str(gm.score)
	else:
		$ScoreLabel.text = "金币: 0"
	$ScoreLabel.add_theme_font_size_override("font_size", 24)
	
	if has_node("GameOverPanel"):
		$GameOverPanel.visible = false
	update_health_bar(_player.health, _player.max_health)
	
	# 初始化玩家等级
	if $PlayerName.text.strip_edges() == "":
		$PlayerName.text = "勇者"
	update_player_level()
	
	# 初始化经验值UI (直接从LevelManager获取数据)
	if has_node("LevelUI/LevelPanel/ExpBar"):
		var level_manager = get_node("/root/LevelManager")
		if level_manager:
			update_exp_bar(level_manager.player_exp, level_manager.exp_to_next_level)
		else:
			print("UIManager: 警告: _initialize_ui 无法找到LevelManager来初始化经验条")
	
	
	# 初始化设置页面 (之前已经移动到 settings_panel.gd，这里不再初始化)
	# initialize_settings_page()
	
	# 初始化天赋页面 (之前已经移动到 talent_panel.gd，这里不再初始化)
	initialize_talent_page()

# 更新血条
func update_health_bar(current_health: float, max_health: float):
	if has_node("HealthBar"):
		var health_bar = $HealthBar
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.get_node("HealthLabel").text = str(int(current_health)) + "/" + str(int(max_health))

# 更新玩家等级显示
func update_player_level():
	print("UIManager: update_player_level() called")
	var level_manager = get_node("/root/LevelManager")
	if has_node("PlayerLevel") and level_manager:
		var level_text = "等级: " + str(level_manager.player_level) + "/" + str(level_manager.player_max_level)
		$PlayerLevel.text = level_text
		print("UIManager: 更新玩家等级到: ", level_text, " (从LevelManager获取: ", level_manager.player_level, "/", level_manager.player_max_level, ")")
		
		# 同步到GameAttributes (已移除此冗余同步)
		# GameAttributes.player_level = level_manager.player_level
	else:
		print("UIManager: 警告: 无法更新PlayerLevel，节点或LevelManager缺失")

# 更新经验条
func update_exp_bar(current_exp: int, required_exp: int):
	if has_node("LevelUI/LevelPanel/ExpBar"):
		var exp_bar = $LevelUI/LevelPanel/ExpBar
		exp_bar.max_value = required_exp
		exp_bar.value = current_exp
	
		# 更新经验值文本
		if has_node("LevelUI/LevelPanel/ExpLabel"):
			$LevelUI/LevelPanel/ExpLabel.text = str(current_exp) + "/" + str(required_exp)
		
		# 根据经验值百分比改变颜色
		var exp_percentage = float(current_exp) / float(required_exp) if required_exp > 0 else 0.0
		if exp_percentage >= 0.7:
			exp_bar.color = Color(0.0, 1.0, 0.0, 1) # 70%以上变绿色
		else:
			exp_bar.color = Color(0.2, 0.6, 1.0, 1) # 默认蓝色

# 初始化天赋页面
func initialize_talent_page():
	if has_node("BottomPanel/天赋"):
		var talent_panel = get_node("BottomPanel/天赋")
		talent_panel.visible = false # 默认隐藏


# 处理游戏结束信号
func _on_game_over_triggered(final_score: int):
	print("UI Manager 收到游戏结束信号，最终得分: ", final_score)
	var game_over_panel = get_node_or_null("GameOverPanel")
	if game_over_panel:
		game_over_panel.visible = true
		var final_score_label = game_over_panel.get_node_or_null("FinalScoreLabel")
		if final_score_label:
			final_score_label.text = "最终得分: " + str(final_score)
			
# 处理游戏重启信号
func _on_game_restarted():
	print("UI Manager 收到游戏重启信号")
	var game_over_panel = get_node_or_null("GameOverPanel")
	if game_over_panel:
		game_over_panel.visible = false
	
	# 在游戏重启时更新钻石显示
	_on_diamonds_changed(GameAttributes.diamonds)

func _on_diamonds_changed(new_diamonds: int):
	print("UI Manager 收到钻石变化信号: ", new_diamonds)
	var diamond_label = get_node_or_null("DiamondLabel")
	if diamond_label:
		diamond_label.text = "钻石: " + str(new_diamonds)

# 存档系统信号处理
# func _on_save_completed():
#	print("收到保存完成信号")
#	close_operation_dialog()
#	show_success_dialog("保存成功", "游戏已成功保存！")
#	update_save_info_display()

# func _on_load_completed():
#	print("收到加载完成信号")
#	close_operation_dialog()
#	show_success_dialog("加载成功", "游戏已成功加载！")
#	
#	# 更新所有UI元素
#	update_save_info_display()

# func _on_save_failed(error_message: String):
#	print("收到保存失败信号: ", error_message)
#	close_operation_dialog()
#	show_error_dialog("保存失败", "保存游戏时发生错误：\n" + error_message)

# func _on_load_failed(error_message: String):
#	print("收到加载失败信号: ", error_message)
#	close_operation_dialog()
#	show_error_dialog("加载失败", "加载游戏时发生错误：\n" + error_message)

# 删除存档完成处理
# func _on_delete_completed():
#	print("收到删除完成信号")
#	close_operation_dialog()
#	show_success_dialog("删除成功", "存档已成功删除！")
#	update_save_info_display()

# func _on_delete_failed(error_message: String):
#	print("收到删除失败信号: ", error_message)
#	close_operation_dialog()
#	show_error_dialog("删除失败", "删除存档时发生错误：\n" + error_message)

# 更新存档信息显示
# func update_save_info_display():
#	var save_info_label = get_node_or_null("BottomPanel/设置/SaveManagerSection/SaveInfoLabel")
#	if not save_info_label:
#		print("存档信息标签不存在，跳过更新")
#		return
#	
#	var save_info = SaveSystem.get_save_info()
#	if not save_info:
#		save_info_label.text = "存档信息: 无存档"
#	else:
#		print("存档信息: ", save_info)
#		save_info_label.text = "存档信息: 等级 " + str(save_info.player_level) + " | 最高关卡 " + str(save_info.highest_level) + " | 总分数 " + str(save_info.total_score)

# 显示操作对话框
func show_operation_dialog(title: String, message: String):
	# 创建背景遮罩
	var background = ColorRect.new()
	background.name = "OperationDialog"
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# 创建对话框
	var dialog = Panel.new()
	dialog.custom_minimum_size = Vector2(300, 150)
	var viewport_size = Vector2(get_viewport().size)
	dialog.position = (viewport_size - dialog.custom_minimum_size) / 2
	background.add_child(dialog)
	
	# 创建内容容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)
	
	# 标题
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 消息
	var message_label = Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message_label)
	
	# 进度条
	var progress_bar = ProgressBar.new()
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.custom_minimum_size = Vector2(250, 20)
	vbox.add_child(progress_bar)
	
	# 进度条动画
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 100, 2.0)

# 显示确认对话框
func show_confirmation_dialog(title: String, message: String, callback_function: String):
	# 创建背景遮罩
	var background = ColorRect.new()
	background.name = "ConfirmationDialog"
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# 创建对话框
	var dialog = Panel.new()
	dialog.custom_minimum_size = Vector2(300, 150)
	var viewport_size = Vector2(get_viewport().size)
	dialog.position = (viewport_size - dialog.custom_minimum_size) / 2
	background.add_child(dialog)
	
	# 创建内容容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)
	
	# 标题
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 消息
	var message_label = Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message_label)
	
	# 按钮容器
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	# 确认按钮
	var confirm_button = Button.new()
	confirm_button.text = "确认"
	confirm_button.connect("pressed", Callable(self, callback_function))
	button_container.add_child(confirm_button)
	
	# 取消按钮
	var cancel_button = Button.new()
	cancel_button.text = "取消"
	cancel_button.connect("pressed", Callable(self, "_on_cancel_confirmation"))
	button_container.add_child(cancel_button)

# 关闭操作对话框
func close_operation_dialog():
	var dialog = get_node_or_null("OperationDialog")
	if dialog:
		dialog.queue_free()

# 显示简单对话框（只有确定按钮）
func show_simple_dialog(title: String, message: String, callback_function: String):
	# 创建背景遮罩
	var background = ColorRect.new()
	background.name = "SimpleDialog"
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# 创建对话框
	var dialog = Panel.new()
	dialog.custom_minimum_size = Vector2(300, 150)
	var viewport_size = Vector2(get_viewport().size)
	dialog.position = (viewport_size - dialog.custom_minimum_size) / 2
	background.add_child(dialog)
	
	# 创建内容容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)
	
	# 标题
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 消息
	var message_label = Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message_label)
	
	# 确定按钮
	var ok_button = Button.new()
	ok_button.text = "确定"
	ok_button.connect("pressed", Callable(self, callback_function))
	vbox.add_child(ok_button)

# 显示成功对话框
func show_success_dialog(title: String, message: String):
	show_simple_dialog(title, message, "_on_success_dialog_ok")

# 显示错误对话框
func show_error_dialog(title: String, message: String):
	show_simple_dialog(title, message, "_on_error_dialog_ok")

# 对话框按钮处理
func _on_success_dialog_ok():
	close_simple_dialog()

func _on_error_dialog_ok():
	close_simple_dialog()

func _on_cancel_confirmation():
	close_confirmation_dialog()

# 关闭简单对话框
func close_simple_dialog():
	var dialog = get_node_or_null("SimpleDialog")
	if dialog:
		dialog.queue_free()

# 关闭确认对话框
func close_confirmation_dialog():
	var dialog = get_node_or_null("ConfirmationDialog")
	if dialog:
		dialog.queue_free()

# 信号处理函数
func _on_player_damaged(_damage: float):
	update_health_bar(_player.health, _player.max_health)

func _on_score_updated(new_score: int):
	$ScoreLabel.text = "金币: " + str(new_score)

func _on_quest_completed(quest_id: String, reward: int):
	print("任务完成: ", quest_id, " 奖励: ", reward)

func _on_achievement_unlocked(achievement_id: String):
	print("成就解锁: ", achievement_id)

func _on_daily_quests_reset():
	print("每日任务已重置")

func _on_player_level_up(level):
	print("UIManager: _on_player_level_up(", level, ") called")
	print("UIManager: 玩家升级到 ", level, " 级")
	
	# 更新玩家等级显示
	update_player_level()
	
	# 更新经验条显示
	update_exp_display()
	
	# 更新关卡显示（如果需要根据等级变化）
	update_level_display()
	
	# 刷新天赋UI以更新天赋点显示和天赋面板
	var level_manager = get_node("/root/LevelManager")
	if level_manager:
		# 更新天赋点显示
		if has_node("BottomPanel/天赋/TalentPointsLabel"):
			$BottomPanel / 天赋 / TalentPointsLabel.text = "可用天赋点: " + str(level_manager.talent_points) + " (每级获得1点)"
		
		# 刷新天赋面板UI
		var talent_panel = get_node_or_null("BottomPanel/天赋")
		if talent_panel and talent_panel.has_method("_refresh"):
			talent_panel._refresh()

func _on_level_started(level_number, level_data):
	print("UIManager: _on_level_started(", level_number, ", ", level_data, ") called")
	update_level_display()
	
func _on_level_progress_updated(current_progress, target_progress):
	print("UIManager: _on_level_progress_updated(", current_progress, ", ", target_progress, ") called")
	update_level_progress(current_progress, target_progress)

func _on_game_attribute_changed(attribute_name: String, value):
	print("UIManager: _on_game_attribute_changed(", attribute_name, ", ", value, ") called")
	match attribute_name:
		"health":
			update_health_bar(value, GameAttributes.max_health)
		"max_health":
			update_health_bar(GameAttributes.health, value)
		"player_level":
			update_player_level()
		"player_experience":
			update_exp_display()
		"experience_required":
			update_exp_display()
		# 可以根据需要添加其他属性的更新逻辑

func _on_talent_points_changed(talent_points):
	print("UIManager: _on_talent_points_changed(", talent_points, ") called")
	print("UIManager: 天赋点变化: ", talent_points)
	# 更新天赋点显示
	if has_node("BottomPanel/天赋/TalentPointsLabel"):
		$BottomPanel / 天赋 / TalentPointsLabel.text = "可用天赋点: " + str(talent_points) + " (每级获得1点)"
	
	# 刷新天赋面板UI
	var talent_panel = get_node_or_null("BottomPanel/天赋")
	if talent_panel and talent_panel.has_method("_refresh"):
		talent_panel._refresh()

# 更新生命值显示
func update_health_display():
	var player = get_node("../Player")
	if player and has_node("BottomPanel/属性/HealthLabel"):
		$BottomPanel / 属性 / HealthLabel.text = "生命值: " + str(player.health) + "/" + str(player.max_health)


# 启动UI更新定时器
func _start_ui_update_timer():
	var timer = Timer.new()
	timer.wait_time = 0.1 # 每0.1秒更新一次
	timer.autostart = true
	timer.connect("timeout", Callable(self, "_on_ui_update_timer_timeout"))
	add_child(timer)

# UI定时更新回调
func _on_ui_update_timer_timeout():
	if not _player or not _game_manager:
		return
	
	# 更新血量显示
	update_health_display()
	
	# 更新金币显示
	# if has_node("ScoreLabel"):
	#	$ScoreLabel.text = "金币: " + str(_game_manager.score)
	
	# 更新关卡显示
	update_level_display()
	
	# 更新经验条
	update_exp_display()
	
	# 更新等级显示
	update_player_level()
	
	# 更新玩家属性
	if has_node("BottomPanel/属性"):
		var attribute_panel = get_node("BottomPanel/属性")
		if attribute_panel.has_method("update_player_stats"):
			attribute_panel.update_player_stats() # 移除参数
	# update_player_stats()

# 更新关卡显示（兼容旧调用方式）
func update_level_display(_level_number = null, _level_data = null):
	print("UIManager: update_level_display() called")
	var level_manager = get_node("/root/LevelManager")
	if has_node("InGameLevelInfo/InGameLevel") and level_manager:
		var current_level_val = level_manager.current_level
		# 计算关卡格式：1-1, 1-2, 1-3, 1-4, 1-5, 2-1...
		var major_level = ((current_level_val - 1) / 5) + 1
		var minor_level = ((current_level_val - 1) % 5) + 1
		var level_text = "关卡: " + str(major_level) + "-" + str(minor_level)
		$InGameLevelInfo/InGameLevel.text = level_text
		print("UIManager: 更新关卡显示到: ", level_text, " (从LevelManager获取: ", current_level_val, ")")
	else:
		print("UIManager: 警告: 无法更新InGameLevel，节点或LevelManager缺失")
	
	# 同时更新关卡进度条
	if level_manager:
		var current_progress_val = level_manager.current_progress
		var target_progress_val = level_manager.target_progress
		update_level_progress(current_progress_val, target_progress_val)
		print("UIManager: 调用 update_level_progress: current=", current_progress_val, ", target=", target_progress_val)
	else:
		print("UIManager: 警告: 无法更新关卡进度条，LevelManager缺失")

# 更新关卡进度条
func update_level_progress(current_progress: int, target_progress: int):
	if has_node("InGameLevelInfo/InGameProgress"):
		var progress_bar = $InGameLevelInfo/InGameProgress
		# 限制进度百分比在0-1之间
		var progress_percentage = clamp(float(current_progress) / float(target_progress) if target_progress > 0 else 0.0, 0.0, 1.0)
		
		# InGameProgress的offset_left是-150，最大宽度是300像素（从-150到150）
		var bar_start = -150.0
		var bar_max_width = 300.0
		progress_bar.offset_right = bar_start + (bar_max_width * progress_percentage)
		
		# 根据进度改变颜色
		if progress_percentage >= 0.8:
			progress_bar.color = Color(0.0, 1.0, 0.0, 1) # 80%以上变绿色
		elif progress_percentage >= 0.5:
			progress_bar.color = Color(1.0, 1.0, 0.0, 1) # 50-80%黄色
		else:
			progress_bar.color = Color(0.2, 0.8, 0.2, 1) # 默认浅绿色

# 更新经验显示
func update_exp_display():
	print("UIManager: update_exp_display() called")
	var level_manager = get_node("/root/LevelManager")
	if not level_manager:
		print("UIManager: 警告: update_exp_display 无法找到LevelManager")
		return
	
	# 使用LevelManager的经验数据，而不是GameAttributes
	var current_exp = level_manager.player_exp
	var required_exp = level_manager.exp_to_next_level
	
	# 同步到GameAttributes (已移除此冗余同步)
	# GameAttributes.player_experience = current_exp
	# GameAttributes.experience_required = required_exp
	
	# 更新经验文本
	if has_node("InGameLevelInfo/ExpLabel"):
		var exp_percentage = int((float(current_exp) / float(required_exp)) * 100) if required_exp > 0 else 0
		$InGameLevelInfo/ExpLabel.text = str(current_exp) + "/" + str(required_exp) + " (" + str(exp_percentage) + "%)"
	
	# 更新经验条（ColorRect类型，通过调整offset_right来显示进度）
	if has_node("InGameLevelInfo/ExpBar"):
		var exp_bar = $InGameLevelInfo/ExpBar
		# 限制经验百分比在0-1之间
		var exp_percentage = clamp(float(current_exp) / float(required_exp) if required_exp > 0 else 0.0, 0.0, 1.0)
		
		# ExpBar的offset_left是-150，最大宽度是300像素（从-150到150）
		var bar_start = -150.0
		var bar_max_width = 300.0
		exp_bar.offset_right = bar_start + (bar_max_width * exp_percentage)
		
		# 根据经验值百分比改变颜色
		if exp_percentage >= 0.7:
			exp_bar.color = Color(0.0, 1.0, 0.0, 1) # 70%以上变绿色
		else:
			exp_bar.color = Color(0.2, 0.6, 1.0, 1) # 蓝色
	else:
		print("UIManager: ⚠️ 经验条节点不存在: InGameLevelInfo/ExpBar")
