extends Node2D

# --- Currency ---
@export var player_money: int = 100
@export var player_rubies: int = 10

# --- Shop setup ---
# Each item: name -> {cost_money, cost_rubies}
var shop_items = {
	"potion": {"money": 20, "rubies": 0},
	"sword": {"money": 50, "rubies": 2},
	"gem": {"money": 0, "rubies": 5},
	"shield": {"money": 30, "rubies": 1},
}

var cart: Array = []
const MAX_CART_ITEMS = 2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Automatically apply the mask to all your bottle buttons here
	setup_bottle_mask($TextureButton)
	setup_bottle_mask($TextureButton2)
	setup_bottle_mask($GaryInfo)
	setup_bottle_mask($garyexit)
	setup_bottle_mask($PumpkinShelf)
	setup_bottle_mask($Shopsign)
	$Flame.play("flame")

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

# --- Shopping cart functions ---

func add_to_cart(item_name: String) -> bool:
	if not shop_items.has(item_name):
		print("Item not found: ", item_name)
		return false

	if cart.size() >= MAX_CART_ITEMS:
		print("Cart full! Max ", MAX_CART_ITEMS, " items per round.")
		return false

	cart.append(item_name)
	print("Added to cart: ", item_name, " (", cart.size(), "/", MAX_CART_ITEMS, ")")
	return true

func remove_from_cart(item_name: String) -> void:
	cart.erase(item_name)

func get_cart_total() -> Dictionary:
	var total_money = 0
	var total_rubies = 0
	for item in cart:
		total_money += shop_items[item]["money"]
		total_rubies += shop_items[item]["rubies"]
	return {"money": total_money, "rubies": total_rubies}

func can_afford_cart() -> bool:
	var total = get_cart_total()
	return player_money >= total["money"] and player_rubies >= total["rubies"]

func checkout() -> bool:
	if cart.is_empty():
		print("Cart is empty.")
		return false

	if not can_afford_cart():
		print("Not enough money/rubies to buy items in cart!")
		return false

	var total = get_cart_total()
	player_money -= total["money"]
	player_rubies -= total["rubies"]

	print("Purchased: ", cart)
	print("Remaining money: ", player_money, " | Remaining rubies: ", player_rubies)

	cart.clear()  # reset cart after buying (new round starts fresh)
	return true

# --- Existing reveal/hide functions ---

func _on_reveal_button_pressed() -> void:
	$Gary.visible = true
func _on_garyexit_pressed() -> void:
	$Gary.visible = false
func _on_pumpkin_shelf_pressed() -> void:
	$Pumpkin.visible = true
func _on_pumpkinexit_pressed() -> void:
	$Pumpkin.visible = false
func _on_shroom_info_pressed() -> void:
	$shroom.visible = true
func _on_shroomexit_pressed() -> void:
	$shroom.visible = false
func _on_spider_shelf_pressed() -> void:
	$spider.visible = true
func _on_spiderexit_pressed() -> void:
	$spider.visible = false
func _on_pootsshelf_pressed() -> void:
	$Poots.visible = true
func _on_pootsexit_pressed() -> void:
	$Poots.visible = false
func _on_moth_shelf_pressed() -> void:
	$Moth.visible = true
func _on_moth_exit_pressed() -> void:
	$Moth.visible = false
func _on_mandrake_shelf_pressed() -> void:
	$Mandrake.visible = true
func _on_mandrakexit_pressed() -> void:
	$Mandrake.visible = false


func _on_settingicon_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
