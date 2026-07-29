extends Control

func _ready() -> void:
	if has_node("PlayerCount"):
		$PlayerCount.min_value = 1
		$PlayerCount.max_value = 15
		if $PlayerCount.value < 1:
			$PlayerCount.value = 2

func _on_start_pressed() -> void:
	var n := 2
	if has_node("PlayerCount"):
		n = int($PlayerCount.value)
	n = clampi(n, 1, 15)
	GameSession.start_local(n)
	get_tree().change_scene_to_file("res://board.tscn")
