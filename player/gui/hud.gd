extends CanvasLayer

@onready var pause_menu := $Pause
@onready var player_inventory := $CombinedInventory


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("god_menu"): ## Swap mouse mode (Open menu eventually)
		if pause_menu.opened: 
			pause_menu.close_menu()
		else: 
			player_inventory.close_menu()
			pause_menu.open_menu()
	
	elif event.is_action_pressed("god_inventory"):
		if player_inventory.opened:
			player_inventory.close_menu()
		else:
			player_inventory.open_menu()
