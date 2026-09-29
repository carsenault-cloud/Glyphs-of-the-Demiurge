extends Control

var opened := false
@onready var hotbar := $VBoxContainer/HotbarUI
@onready var inventory := $VBoxContainer/InventoryUI

func _ready() -> void:
	close_menu()
	hotbar.visible = true

func open_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	inventory.visible = true
	opened = true

func close_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory.visible = false
	opened = false
