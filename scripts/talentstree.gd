extends VBoxContainer

var talents_node

func _ready():
	talents_node = get_node("/root/Talents")
	# 移除旧的信号连接，因为天赋点和等级由LevelManager管理
	# talents_node.connect("talent_point_used", Callable(self, "_refresh"))
	# talents_node.connect("talent_unlocked", Callable(self, "_refresh"))
	
	var level_manager = get_node("/root/LevelManager")
	if level_manager:
		level_manager.connect("player_level_up", Callable(self, "_refresh"))
		level_manager.connect("talent_points_changed", Callable(self, "_refresh"))
	else:
		print("Talentstree: 警告: 无法找到LevelManager节点，无法连接信号")
	_refresh()

func _refresh(_arg = null): # 添加一个可选参数以匹配信号
	# 清空旧UI
	for c in get_children():
		c.queue_free()
	# 显示可用点数
	var points_label = Label.new()
	points_label.text = "可用天赋点: " + str(talents_node.get_remaining_talent_points())
	add_child(points_label)
	
	var level_manager = get_node("/root/LevelManager") # 获取LevelManager
	if not level_manager:
		print("Talentstree: 无法找到LevelManager节点")
		return
	
	var player_current_level = level_manager.player_level
	var available_talent_points = level_manager.talent_points

	# 遍历所有天赋
	for tid in talents_node.talent_definitions.keys():
		var def = talents_node.talent_definitions[tid]
		var current_talent_level = talents_node.get_talent_level(tid)
		var hbox = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = def.name + " (Lv." + str(current_talent_level) + "/" + str(def.max_level) + ")"
		hbox.add_child(name_label)

		var desc_text = ""
		if current_talent_level > 0:
			desc_text = def.descriptions[current_talent_level - 1]
		else:
			desc_text = "未解锁"
		var desc_label = Label.new()
		desc_label.text = desc_text
		hbox.add_child(desc_label)

		var btn = Button.new()
		btn.text = "升级"
		
		var can_upgrade_check = talents_node.can_upgrade_talent(tid, available_talent_points)
		btn.disabled = not can_upgrade_check.ok
		
		# 显示升级需求
		var requirement_label = Label.new()
		if current_talent_level < def.max_level:
			var required_level_for_next = def.required_levels[current_talent_level]
			var cost_for_next = def.cost_per_level[current_talent_level]
			requirement_label.text = " [等级: " + str(required_level_for_next) + ", 点数: " + str(cost_for_next) + "]"
			if not can_upgrade_check.ok:
				requirement_label.text += " (" + can_upgrade_check.reason + ")"
		else:
			requirement_label.text = " [已满级]"
		hbox.add_child(requirement_label)
		
		btn.connect("pressed", Callable(self, "_on_upgrade_pressed").bind(tid))
		hbox.add_child(btn)
		add_child(hbox)

func _on_upgrade_pressed(talent_id):
	if talents_node:
		var level_manager = get_node("/root/LevelManager")
		if level_manager:
			talents_node.upgrade_talent(talent_id, level_manager.talent_points) # 传入LevelManager的实际天赋点数
		else:
			print("Talentstree: 无法找到LevelManager，无法升级天赋")
