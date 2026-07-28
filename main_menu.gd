extends Node2D


func _on_check_button_pressed() -> void:
	var n := 2
	if has_node("PlayerCount"):
		n = int($PlayerCount.value)
	n = clampi(n, 1, 15)
	GameSession.start_local(n)
	get_tree().change_scene_to_file("res://board.tscn")
