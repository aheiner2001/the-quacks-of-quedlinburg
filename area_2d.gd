@tool
extends Node2D # (Or whatever node type your board scene root is)

# Click this checkbox in the Inspector of your board scene to auto-number them!
@export var run_auto_numbering: bool = false:
	set(value):
		auto_number_stones()

func _ready() -> void:
	if Engine.is_editor_hint():
		return # Prevents game code from running awkwardly while editing
		
	# Put your normal board game code here


func auto_number_stones() -> void:
	var current_number = 1
	
	# Looks through all children inside the board scene
	for child in get_children():
		if "stone_value" in child:
			child.stone_value = current_number
			current_number += 1
			
	print("Successfully auto-numbered ", current_number - 1, " stones on the board!")
