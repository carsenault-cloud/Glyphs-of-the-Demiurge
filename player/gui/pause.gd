extends Control

var opened := false

func _ready() -> void:
	close_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("god_menu"): ## Swap mouse mode (Open menu eventually)
		if opened: close_menu()
		else: open_menu()

func open_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	visible = true
	opened = true

func close_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	visible = false
	opened = false

func quit() -> void:
	pass
