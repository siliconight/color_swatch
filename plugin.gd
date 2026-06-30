@tool
extends EditorPlugin

## Color Swatch — a simple color-memory dock. Standalone: no other add-on
## required. Enable in Project Settings → Plugins and the dock appears on the
## right.

var _dock: Control


func _enter_tree() -> void:
	_dock = preload("res://addons/color_swatch/color_swatch_dock.gd").new()
	_dock.name = "Color Swatch"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
