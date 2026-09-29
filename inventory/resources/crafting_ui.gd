extends Control

@export var grid_slot_scene: PackedScene
@export var grid_container: GridContainer
@export var output_slot: InventorySlot
var player_inventory: PlayerInventory

func _ready() -> void:
	player_inventory = get_tree().get_first_node_in_group("player_inventory")
	for i in player_inventory.crafting.grid.size:
		var slot: InventorySlot = grid_slot_scene.instantiate()
		grid_container.add_child(slot)
		slot.bind(player_inventory.crafting.grid, i)
	
	output_slot.bind(player_inventory.crafting.output, 0)
