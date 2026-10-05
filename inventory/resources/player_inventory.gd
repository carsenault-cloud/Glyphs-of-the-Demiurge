class_name PlayerInventory
extends Node

const HOTBAR_SIZE := 10
const BACKPACK_SIZE := 30

var storage := Inventory.new(HOTBAR_SIZE + BACKPACK_SIZE)
var selected_slot := 0

var crafting_recognizer := CraftingRecognizer.new()
var crafting: CraftingStation

func _ready() -> void:
	crafting = CraftingStation.new(9, RecipeRegistry.recognizer, "inventory")
	add_to_group("player_inventory")

func _unhandled_input(event: InputEvent) -> void:
	for i in 10:
		var action := "god_hotbar_%d" % [(i + 1)]   # keys 1-9, 0 -> slot 9
		if event.is_action_pressed(action):
			selected_slot = i
			return

func get_selected_stack() -> ItemStack:
	#print("get_selected_stack: firing")
	return storage.get_stack(selected_slot)

func use_selected(user: Node) -> void:
	var s := get_selected_stack()
	if s != null and s.item is UsableItem:
		(s.item as UsableItem).use(user)

func to_save_data() -> Dictionary:
	return {"storage": storage.to_save_array(), "selected_slot": selected_slot}

func load_save_data(d: Dictionary) -> void:
	storage.load_from_save_array(d.get("storage", []))
	selected_slot = int(d.get("selected_slot", 0))
