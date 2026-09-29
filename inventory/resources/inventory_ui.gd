extends Control

@export var slot_scene: PackedScene
@export var slot_container: GridContainer
var player_inventory: PlayerInventory

func _ready() -> void:
	player_inventory = get_tree().get_first_node_in_group("player_inventory")
	visible = false
	for i in PlayerInventory.BACKPACK_SIZE:
		var slot: InventorySlot = slot_scene.instantiate()
		slot_container.add_child(slot)
		slot.bind(player_inventory.storage, PlayerInventory.HOTBAR_SIZE + i)
