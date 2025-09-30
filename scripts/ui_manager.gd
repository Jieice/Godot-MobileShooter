extends CanvasLayer

# UI管理器 - 负责管理所有游戏UI元素
signal ui_ready

var _player: CharacterBody2D
var _game_manager: Node

func _ready():
	print("UI管理器初始化开始")
	
	# 获取玩家引用
	_player = get_node("../Player")
	if not _player:
		print("警告: 无法找到Player节点")
		return
	
	# 获取游戏管理器引用
	_game_manager = get_node("../GameManager")
	if not _game_manager:
		print("警告: 无法找到GameManager节点")
		return
	
	# 连接信号
	_connect_signals()
	
	# 初始化UI
	_initialize_ui()
	
	print("UI管理器初始化完成")
	emit_signal("ui_ready")

func _connect_signals():
	# 连接玩家信号
	if _player.has_signal("player_damaged"):
		_player.connect("player_damaged", Callable(self, "_on_player_damaged"))
	
	# 连接游戏管理器信号
	if _game_manager.has_signal("score_updated"):
		_game_manager.connect("score_updated", Callable(self, "_on_score_updated"))
	
	# 连接存档系统信号
	var save_system = get_node("/root/SaveSystem")
	if save_system:
		save_system.connect("save_completed", Callable(self, "_on_save_completed"))
		save_system.connect("load_completed", Callable(self, "_on_load_completed"))
		save_system.connect("save_failed", Callable(self, "_on_save_failed"))
		save_system.connect("load_failed", Callable(self, "_on_load_failed"))
		save_system.connect("delete_completed", Callable(self, "_on_delete_completed"))
		save_system.connect("delete_failed", Callable(self, "_on_delete_failed"))
	
	# 连接任务系统信号
	var quest_system = get_node("/root/QuestSystem")
	if quest_system:
		quest_system.connect("quest_completed", Callable(self, "_on_quest_completed"))
		quest_system.connect("achievement_unlocked", Callable(self, "_on_achievement_unlocked"))
		quest_system.connect("daily_quests_reset", Callable(self, "_on_daily_quests_reset"))

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
	
	# 初始化经验值UI
	if has_node("LevelUI/LevelPanel/ExpBar"):
		update_exp_bar(GameAttributes.player_experience, GameAttributes.experience_required)
	
	# 初始化MOD强化页面
	initialize_mod_enhancement_page()
	
	# 初始化设置页面
	initialize_settings_page()

# 更新血条
func update_health_bar(current_health: float, max_health: float):
	if has_node("HealthBar"):
		var health_bar = $HealthBar
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.get_node("HealthLabel").text = str(int(current_health)) + "/" + str(int(max_health))

# 更新玩家等级显示
func update_player_level():
	if has_node("PlayerLevel"):
		var level_text = "等级: " + str(GameAttributes.player_level) + "/30"
		$PlayerLevel.text = level_text

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

# 更新玩家属性显示
func update_player_stats():
	var player = get_node("../Player")
	if not player:
		return
	
	# 更新属性面板
	if has_node("BottomPanel/属性"):
		var stats_container = $BottomPanel / 属性
		
		# 更新防御穿透
		if stats_container.has_node("PenetrationLabel"):
			stats_container.get_node("PenetrationLabel").text = "防御穿透: " + str(int(GameAttributes.penetration * 100)) + "%"
		else:
			# 如果标签不存在，创建一个新的
			var penetration_label = Label.new()
			penetration_label.name = "PenetrationLabel"
			penetration_label.text = "防御穿透: " + str(int(GameAttributes.penetration * 100)) + "%"
			stats_container.add_child(penetration_label)
		
		# 更新穿透数量
		if stats_container.has_node("PenetrationCountLabel"):
			stats_container.get_node("PenetrationCountLabel").text = "穿透数量: " + str(GameAttributes.penetration_count)
		else:
			# 如果标签不存在，创建一个新的
			var penetration_count_label = Label.new()
			penetration_count_label.name = "PenetrationCountLabel"
			penetration_count_label.text = "穿透数量: " + str(GameAttributes.penetration_count)
			stats_container.add_child(penetration_count_label)
	
	# 更新生命值显示
	if has_node("BottomPanel/属性/HealthLabel"):
		$BottomPanel / 属性 / HealthLabel.text = "生命值: " + str(player.health) + "/" + str(player.max_health)
	else:
		# 创建生命值标签
		var health_label = Label.new()
		health_label.name = "HealthLabel"
		if player:
			health_label.text = "生命值: " + str(player.health) + "/" + str(player.max_health)
		else:
			health_label.text = "生命值: 0/0"
		$BottomPanel / 属性.add_child(health_label)
		
	# 更新攻击速度显示
	if has_node("BottomPanel/属性/AttackSpeedLabel"):
		$BottomPanel / 属性 / AttackSpeedLabel.text = "攻击速度: " + str(snapped(GameAttributes.attack_speed, 0.1)) + "x"
	else:
		# 创建攻击速度标签
		var attack_speed_label = Label.new()
		attack_speed_label.name = "AttackSpeedLabel"
		attack_speed_label.text = "攻击速度: " + str(snapped(GameAttributes.attack_speed, 0.1)) + "x"
		$BottomPanel / 属性.add_child(attack_speed_label)
	
	# 更新防御显示
	if has_node("BottomPanel/属性/DefenseLabel"):
		$BottomPanel / 属性 / DefenseLabel.text = "防御: " + str(snappedf(GameAttributes.defense * 100, 0.1)) + "%"
	else:
		# 创建防御标签
		var defense_label = Label.new()
		defense_label.name = "DefenseLabel"
		defense_label.text = "防御: " + str(snappedf(GameAttributes.defense * 100, 0.1)) + "%"
		$BottomPanel / 属性.add_child(defense_label)
		
	# 更新闪避率显示
	if has_node("BottomPanel/属性/DodgeChanceLabel"):
		$BottomPanel / 属性 / DodgeChanceLabel.text = "闪避率: " + str(snappedf(GameAttributes.dodge_chance * 100, 0.1)) + "%"
	else:
		# 创建闪避率标签
		var dodge_label = Label.new()
		dodge_label.name = "DodgeChanceLabel"
		dodge_label.text = "闪避率: " + str(snappedf(GameAttributes.dodge_chance * 100, 0.1)) + "%"
		$BottomPanel / 属性.add_child(dodge_label)

# 初始化MOD强化页面
func initialize_mod_enhancement_page():
	print("初始化MOD强化页面")
	
	# 更新MOD插槽显示
	update_mod_slots()
	
	# 更新MOD库存显示
	update_mod_inventory()
	
	# 更新容量显示
	update_capacity_display()

# 更新MOD插槽显示
func update_mod_slots():
	if not has_node("BottomPanel/TabContainer/MOD强化/MODSlotsContainer"):
		return
		
	var slots_container = $BottomPanel/TabContainer/MOD强化/MODSlotsContainer
	
	# 清除现有插槽
	for child in slots_container.get_children():
		child.queue_free()
	
	# 创建MOD插槽
	for i in range(ModSystem.player_core_module.max_mods):
		var slot_bg = ColorRect.new()
		slot_bg.name = "ModSlot" + str(i)
		slot_bg.custom_minimum_size = Vector2(80, 80)
		slot_bg.color = Color(0.3, 0.3, 0.3, 0.8)
		slot_bg.border_width = 2
		slot_bg.border_color = Color(0.6, 0.6, 0.6)
		slots_container.add_child(slot_bg)
		
		# 添加插槽标签
		var slot_label = Label.new()
		slot_label.text = "插槽 " + str(i + 1)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 12)
		slot_bg.add_child(slot_label)
		
		# 连接点击事件
		slot_bg.connect("gui_input", Callable(self, "_on_mod_slot_clicked").bind(i))
		
		# 显示已装备的MOD
		if i < ModSystem.player_core_module.equipped_mods.size() and ModSystem.player_core_module.equipped_mods[i] != "":
			var mod_id = ModSystem.player_core_module.equipped_mods[i]
			var mod_info = ModSystem.get_mod_info(mod_id)
			if mod_info:
				slot_label.text = mod_info.name
			else:
				slot_label.text = "未知MOD"
		else:
			slot_label.text = "空"

# 更新MOD库存显示
func update_mod_inventory():
	if not has_node("BottomPanel/TabContainer/MOD强化/ModInventoryContainer"):
		return
		
	var inventory_container = $BottomPanel/TabContainer/MOD强化/ModInventoryContainer
	
	# 清除现有库存
	for child in inventory_container.get_children():
		child.queue_free()
	
	# 显示所有MOD
	for mod_id in ModSystem.mod_inventory:
		var mod_info = ModSystem.get_mod_info(mod_id)
		if mod_info:
			var mod_button = Button.new()
			mod_button.text = mod_info.name
			mod_button.custom_minimum_size = Vector2(200, 40)
			mod_button.connect("pressed", Callable(self, "_on_mod_button_pressed").bind(mod_id))
			inventory_container.add_child(mod_button)

# 更新容量显示
func update_capacity_display():
	if not has_node("BottomPanel/TabContainer/MOD强化/CapacityLabel"):
		return
	
	var used_capacity = ModSystem.calculate_used_capacity()
	var max_capacity = ModSystem.player_core_module.max_capacity
	$BottomPanel/TabContainer/MOD强化/CapacityLabel.text = "容量: " + str(used_capacity) + "/" + str(max_capacity)

# MOD插槽点击处理
func _on_mod_slot_clicked(slot_index: int, event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("点击MOD插槽: ", slot_index)
		
		# 如果插槽有MOD，卸下它
		if slot_index < ModSystem.player_core_module.equipped_mods.size() and ModSystem.player_core_module.equipped_mods[slot_index] != "":
			var mod_id = ModSystem.player_core_module.equipped_mods[slot_index]
			ModSystem.unequip_mod(slot_index)
			print("卸下MOD: ", mod_id, " 从插槽 ", slot_index)
		else:
			print("插槽 ", slot_index, " 为空")

# MOD按钮点击处理
func _on_mod_button_pressed(mod_id: String):
	print("点击MOD按钮: ", mod_id)
	
	# 尝试装备MOD
	var success = false
	for i in range(ModSystem.player_core_module.max_mods):
		if ModSystem.player_core_module.equipped_mods[i] == "":
			if ModSystem.equip_mod(mod_id, i):
				success = true
				break
	
	if not success:
		print("无法装备MOD: ", mod_id, " - 容量不足或插槽已满")

# MOD装备信号处理
func _on_mod_equipped(mod_id, slot_index):
	print("MOD装备: ", mod_id, " 到插槽 ", slot_index)
	update_mod_slots()
	update_capacity_display()
	update_player_stats()

func _on_mod_unequipped(mod_id, slot_index):
	print("MOD卸下: ", mod_id, " 从插槽 ", slot_index)
	update_mod_slots()
	update_capacity_display()
	update_player_stats()

# 初始化设置页面
func initialize_settings_page():
	print("初始化设置页面")
	
	# 连接存档管理按钮
	var save_button = get_node_or_null("BottomPanel/设置/SaveManagerSection/SaveButtonsContainer/SaveButton")
	var load_button = get_node_or_null("BottomPanel/设置/SaveManagerSection/SaveButtonsContainer/LoadButton")
	var delete_button = get_node_or_null("BottomPanel/设置/SaveManagerSection/SaveButtonsContainer/DeleteButton")
	
	if save_button and not save_button.is_connected("pressed", Callable(self, "_on_save_button_pressed")):
		save_button.connect("pressed", Callable(self, "_on_save_button_pressed"))
	
	if load_button and not load_button.is_connected("pressed", Callable(self, "_on_load_button_pressed")):
		load_button.connect("pressed", Callable(self, "_on_load_button_pressed"))
	
	if delete_button and not delete_button.is_connected("pressed", Callable(self, "_on_delete_button_pressed")):
		delete_button.connect("pressed", Callable(self, "_on_delete_button_pressed"))
	
	# 更新存档信息显示
	update_save_info_display()
	
	# 创建游戏设置区域（如果不存在）
	if not has_node("BottomPanel/设置/GameSettingsSection"):
		create_game_settings_section($BottomPanel / 设置)

# 创建游戏设置区域
func create_game_settings_section(parent):
	var game_settings_container = VBoxContainer.new()
	game_settings_container.name = "GameSettingsSection"
	parent.add_child(game_settings_container)
	
	# 分隔线
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	game_settings_container.add_child(separator)
	
	# 游戏设置标题
	var settings_title = Label.new()
	settings_title.text = "游戏设置"
	settings_title.add_theme_font_size_override("font_size", 18)
	settings_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	game_settings_container.add_child(settings_title)

# 存档按钮处理函数
func _on_save_button_pressed():
	print("用户点击保存按钮")
	show_operation_dialog("正在保存游戏...", "保存中，请稍候...")
	SaveSystem.save_game()

func _on_load_button_pressed():
	print("用户点击加载按钮")
	show_operation_dialog("正在加载游戏...", "加载中，请稍候...")
	SaveSystem.load_game()

func _on_delete_button_pressed():
	print("用户点击删除按钮")
	show_confirmation_dialog("确认删除", "确定要删除存档吗？此操作不可撤销！", "_on_delete_confirmed")

func _on_delete_confirmed():
	print("用户确认删除存档")
	close_confirmation_dialog() # 关闭确认对话框
	show_operation_dialog("正在删除存档...", "删除中，请稍候...")
	SaveSystem.delete_save()

# 存档系统信号处理
func _on_save_completed():
	print("收到保存完成信号")
	close_operation_dialog()
	show_success_dialog("保存成功", "游戏已成功保存！")
	update_save_info_display()

func _on_load_completed():
	print("收到加载完成信号")
	close_operation_dialog()
	show_success_dialog("加载成功", "游戏已成功加载！")
	
	# 更新所有UI元素
	update_save_info_display()
	update_player_stats()
	update_health_display()
	
	# 重新初始化MOD相关UI
	initialize_mod_equipment_page()
	update_mod_inventory()
	update_mod_slots()

func _on_save_failed(error_message: String):
	print("收到保存失败信号: ", error_message)
	close_operation_dialog()
	show_error_dialog("保存失败", "保存游戏时发生错误：\n" + error_message)

func _on_load_failed(error_message: String):
	print("收到加载失败信号: ", error_message)
	close_operation_dialog()
	show_error_dialog("加载失败", "加载游戏时发生错误：\n" + error_message)

# 删除存档完成处理
func _on_delete_completed():
	print("收到删除完成信号")
	close_operation_dialog()
	show_success_dialog("删除成功", "存档已成功删除！")
	update_save_info_display()

func _on_delete_failed(error_message: String):
	print("收到删除失败信号: ", error_message)
	close_operation_dialog()
	show_error_dialog("删除失败", "删除存档时发生错误：\n" + error_message)

# 更新存档信息显示
func update_save_info_display():
	var save_info_label = get_node_or_null("BottomPanel/设置/SaveManagerSection/SaveInfoLabel")
	if not save_info_label:
		print("存档信息标签不存在，跳过更新")
		return
	
	var save_info = SaveSystem.get_save_info()
	if not save_info:
		save_info_label.text = "存档信息: 无存档"
	else:
		print("存档信息: ", save_info)
		save_info_label.text = "存档信息: 等级 " + str(save_info.player_level) + " | 最高关卡 " + str(save_info.highest_level) + " | 总分数 " + str(save_info.total_score)

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

# 更新生命值显示
func update_health_display():
	var player = get_node("../Player")
	if player and has_node("BottomPanel/属性/HealthLabel"):
		$BottomPanel / 属性 / HealthLabel.text = "生命值: " + str(player.health) + "/" + str(player.max_health)

# 初始化MOD装备页面
func initialize_mod_equipment_page():
	# 这里可以添加MOD装备页面的初始化逻辑
	pass
