extends Control

@export var slot_scene: PackedScene
@export var slot_container: HBoxContainer
var player_inventory: PlayerInventory

func _ready() -> void:
	player_inventory = get_tree().get_first_node_in_group("player_inventory")
	for i in PlayerInventory.HOTBAR_SIZE:
		var slot: InventorySlot = slot_scene.instantiate()
		slot_container.add_child(slot)
		slot.bind(player_inventory.storage, i, true)

func _process(_delta: float) -> void:
	for i in slot_container.get_child_count():
		var slot: InventorySlot = slot_container.get_child(i)
		slot.modulate = Color.WHITE if i == player_inventory.selected_slot else Color(0.6, 0.6, 0.6	)
