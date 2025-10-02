extends VBoxContainer

var talents_node: Node = null

func _ready():
	print("Talent panel ready")
	talents_node = get_node_or_null("/root/Talents")
	print("talents_node:", talents_node)
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		level_manager.connect("talent_points_changed", Callable(self, "_refresh"))
		level_manager.connect("player_level_up", Callable(self, "_refresh"))
	_refresh()

func _refresh(_arg = null):
	print("refresh called")
	if not talents_node:
		print("talents_node is null, abort refresh")
		return

	var list = get_node_or_null("TalentScroll/TalentList")
	print("TalentList node:", list)
	if not list:
		print("TalentList not found!")
		return
	for c in list.get_children():
		c.queue_free()

	var level_manager = get_node("/root/LevelManager")
	var points = 0
	if level_manager:
		points = level_manager.talent_points
	var points_label = Label.new()
	points_label.text = "可用天赋点: " + str(points)
	points_label.add_theme_font_size_override("font_size", 16)
	points_label.add_theme_color_override("font_color", Color(1, 1, 0.5, 1))
	list.add_child(points_label)

	print("刷新天赋面板，当前可用天赋点：", talents_node.get_remaining_talent_points())
	for tid in talents_node.talent_definitions.keys():
		var def = talents_node.talent_definitions[tid]
		var current_level = talents_node.get_talent_level(tid)
		var can_upgrade_check = talents_node.can_upgrade_talent(tid, talents_node.get_remaining_talent_points())
		print("天赋ID:", tid, "can_upgrade_check:", can_upgrade_check)

		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.custom_minimum_size = Vector2(0, 60)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 0)
		var name_label = Label.new()
		name_label.text = "%s (Lv.%d/%d)" % [def.name, current_level, def.max_level]
		name_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(name_label)
		var desc_text = def.descriptions[0] if def.descriptions.size() > 0 else ""
		if not can_upgrade_check.ok and can_upgrade_check.reason != "":
			desc_text += "\n[" + can_upgrade_check.reason + "]"
		var desc_label = Label.new()
		desc_label.text = desc_text
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.modulate = Color(0.8, 0.8, 0.8, 1)
		vbox.add_child(desc_label)
		hbox.add_child(vbox)

		var progress = ProgressBar.new()
		progress.value = current_level
		progress.max_value = def.max_level
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.custom_minimum_size = Vector2(120, 24)
		hbox.add_child(progress)

		var btn = Button.new()
		btn.text = "升级"
		btn.custom_minimum_size = Vector2(60, 40)
		btn.size_flags_horizontal = Control.SIZE_FILL
		btn.disabled = not can_upgrade_check.ok
		btn.connect("pressed", Callable(self, "_on_upgrade_pressed").bind(tid))
		hbox.add_child(btn)

		var talent_vbox = VBoxContainer.new()
		talent_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		talent_vbox.add_child(hbox)
		list.add_child(talent_vbox)

func _on_upgrade_pressed(talent_id):
	if talents_node:
		var upgraded = talents_node.upgrade_talent(talent_id, talents_node.get_remaining_talent_points())
		if upgraded:
			_refresh() # 立即刷新UI
