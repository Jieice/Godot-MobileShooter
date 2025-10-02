extends AudioStreamPlayer

func _ready():
		if not playing:
			play()
