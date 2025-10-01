extends VBoxContainer

var talents_node: Node = null

func _ready():
    talents_node = get_node_or_null("/root/Talents")
    if talents_node:
        # talents_node.connect("talent_point_used", Callable(self, "_refresh")) # 移除此行，避免重复刷新
        # talents_node.connect("talent_unlocked", Callable(self, "_refresh")) # 移除此行，避免重复刷新
        pass # 确保if块不为空
    _refresh()

func _refresh():
    if not talents_node:
        return

    # 移除旧的“可用天赋点”标签（如果有）
    for child in get_children():
        if child is Label and child.name == "AvailableTalentPointsLabel": # 给Label一个唯一的名字
            child.queue_free()

    # 更新点数显示
    var points_label = Label.new()
    points_label.name = "AvailableTalentPointsLabel"
    points_label.text = "可用天赋点: " + str(talents_node.get_remaining_talent_points())
    add_child(points_label)

    # 清空天赋列表
    var list = get_node("TalentList")
    for c in list.get_children():
        c.queue_free()

    # 遍历所有天赋
    for tid in talents_node.talent_definitions.keys():
        var def = talents_node.talent_definitions[tid]
        var current_level = talents_node.get_talent_level(tid)
        var hbox = HBoxContainer.new()

        var name_label = Label.new()
        name_label.text = def.name + " (Lv." + str(current_level) + "/" + str(def.max_level) + ")"
        hbox.add_child(name_label)

        var desc_label = Label.new()
        if current_level > 0:
            # 显示当前等级的效果描述
            desc_label.text = def.descriptions[current_level - 1]
        else:
            # 未解锁时显示解锁所需等级和点数
            var required_level_info = ""
            if def.required_levels.size() > 0:
                required_level_info = "[需要等级: " + str(def.required_levels[0]) + ", 点数: " + str(def.cost_per_level[0]) + "]"
            desc_label.text = "未解锁 " + required_level_info
        hbox.add_child(desc_label)

        var btn = Button.new()
        btn.text = "升级"
        # 修正disabled状态判断
        var can_upgrade_result = talents_node.can_upgrade_talent(tid, talents_node.get_remaining_talent_points())
        btn.disabled = not can_upgrade_result.ok

        # 只有在可以升级时才连接信号，避免不必要的连接
        if not btn.disabled:
            btn.connect("pressed", Callable(self, "_on_upgrade_pressed").bind(tid))
        hbox.add_child(btn)
        list.add_child(hbox)

func _on_upgrade_pressed(talent_id):
    if talents_node:
        var upgraded = talents_node.upgrade_talent(talent_id)
        if upgraded:
            _refresh() # 立即刷新UI
