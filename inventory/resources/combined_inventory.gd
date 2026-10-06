extends Control

var opened := false
@onready var hotbar := $HBoxContainer/VBoxContainer/HotbarUI
@onready var inventory := $HBoxContainer/VBoxContainer/InventoryUI
@onready var crafting := $HBoxContainer/CraftingUI

func _ready() -> void:
	close_menu()
	hotbar.visible = true

func open_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	inventory.visible = true
	crafting.visible = true
	opened = true

func close_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory.visible = false
	crafting.visible = false
	opened = false
	if CursorHeld.stack != null:
		CursorHeld.drop_held_item()

func _gui_input(event: InputEvent) -> void:
	if opened and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if CursorHeld.stack != null:
			CursorHeld.drop_held_item()
