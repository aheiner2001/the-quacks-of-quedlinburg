extends Node2D


func _on_check_button_pressed() -> void:
	var two := false
	if has_node("Players2"):
		two = $Players2.button_pressed
	GameSession.start_local(2 if two else 1)
	get_tree().change_scene_to_file("res://board.tscn")
