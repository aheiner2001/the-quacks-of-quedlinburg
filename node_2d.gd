extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Automatically apply the mask to all your bottle buttons here
	setup_bottle_mask($TextureButton)
	setup_bottle_mask($TextureButton2)
	setup_bottle_mask($GaryInfo)
	setup_bottle_mask($garyexit)

# Reusable helper function to keep your code clean
func setup_bottle_mask(btn: TextureButton) -> void:
	if btn and btn.texture_normal:
		var img = btn.texture_normal.get_image()
		var bm = BitMap.new()
		bm.create_from_image_alpha(img)
		btn.texture_click_mask = bm

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_reveal_button_pressed() -> void:
	$Gary.visible = true


func _on_garyexit_pressed() -> void:
	$Gary.visible = false
