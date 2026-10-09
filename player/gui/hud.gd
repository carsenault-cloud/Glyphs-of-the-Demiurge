extends CanvasLayer

@onready var pause_menu := $Pause
@onready var player_inventory := $CombinedInventory

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("god_menu"): ## Swap mouse mode (Open menu eventually)
		if pause_menu.opened: 
			pause_menu.close_menu()
		else: 
			player_inventory.close_menu()
			_close_build_menu()
			pause_menu.open_menu()
	
	elif event.is_action_pressed("god_inventory"):
		if player_inventory.opened:
			player_inventory.close_menu()
		else:
			_close_build_menu()
			player_inventory.open_menu()

func _close_build_menu() -> void:
	var bmc: BuildModeController = get_tree().get_first_node_in_group("build_mode_controller")
	if bmc != null:
		bmc.close_menu()
