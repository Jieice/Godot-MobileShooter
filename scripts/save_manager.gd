extends Node

var save_path := "user://player_save.json"

var save_data := {
	"player_level": 1,
	"player_exp": 0,
	"talent_points": 0,
	"total_talent_points": 0,
	"player_talents": {},
	"coins": 0,
	"diamonds": 0,
	"current_level": 1
}

func _ready():
	load_game()

func save_game():
	var lm = get_node_or_null("/root/LevelManager")
	var talents = get_node_or_null("/root/Talents")
	if lm:
		save_data.player_level = lm.player_level
		save_data.player_exp = lm.player_exp
		save_data.talent_points = lm.talent_points
		save_data.total_talent_points = lm.total_talent_points
		save_data.current_level = lm.current_level
	if talents:
		save_data.player_talents = talents.player_talents.duplicate(true)
	save_data.coins = GameAttributes.score
	save_data.diamonds = GameAttributes.diamonds
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	print("游戏进度已保存")

func load_game():
	if not FileAccess.file_exists(save_path):
		print("无存档，首次启动")
		return
	Global.is_loading_save = true
	var file = FileAccess.open(save_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var loaded = JSON.parse_string(content)
	if typeof(loaded) == TYPE_DICTIONARY:
		save_data = loaded
		var lm = get_node_or_null("/root/LevelManager")
		var talents = get_node_or_null("/root/Talents")
		if lm:
			lm.player_level = save_data.player_level
			lm.player_exp = save_data.player_exp
			lm.talent_points = save_data.talent_points
			lm.total_talent_points = save_data.total_talent_points
			lm.current_level = save_data.current_level
			lm.start_level(lm.current_level)
		if talents:
			talents.player_talents = save_data.player_talents.duplicate(true)
			for tid in talents.player_talents.keys():
				var level = talents.player_talents[tid]
				for i in range(level):
					talents.apply_talent_effect(tid, i + 1)
		GameAttributes.score = save_data.coins
		GameAttributes.diamonds = save_data.diamonds
		if GameAttributes.has_signal("attributes_changed"):
			GameAttributes.emit_signal("attributes_changed", "score", GameAttributes.score)
			GameAttributes.emit_signal("attributes_changed", "diamonds", GameAttributes.diamonds)
		var ui = get_node_or_null("/root/Main/UI")
		if ui and ui.has_method("_on_score_updated"):
			ui._on_score_updated(GameAttributes.score)
		print("游戏进度已恢复")
	else:
		print("存档损坏或格式错误")
	Global.is_loading_save = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
