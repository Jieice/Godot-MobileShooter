extends Control

var delay := 2.0

func _ready():
    await get_tree().create_timer(delay).timeout
    _goto_main()

func _input(event):
    if event is InputEventMouseButton and event.pressed:
        _goto_main()

func _goto_main():
    get_tree().change_scene_to_file("res://scenes/main.tscn")
