@tool
extends Node2D

@export var run_auto_numbering: bool = false:
	set(value):
		auto_number_stones()

func _ready() -> void:
	if Engine.is_editor_hint():
		return

func auto_number_stones() -> void:
	var current_number = 1
	var children = get_children()
	
	print("--- DEBUG: Checking board children ---")
	print("Total children found: ", children.size())
	
	for child in children:
		print("Found child named: ", child.name, " of type: ", child.get_class())
		
		if child.has_node("Label"):
			var lbl = child.get_node("Label") as Label
			if lbl:
				lbl.text = str(current_number)
				print(" -> Successfully numbered stone: ", current_number)
				current_number += 1
		else:
			print(" -> WARNING: Child '", child.name, "' does NOT have a child node named 'Label'!")
			
	print("Successfully auto-numbered ", current_number - 1, " stones on the board!")
