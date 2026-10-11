extends Node
class TestSettings extends "res://Settings.gd":
	var saves := 0
	func _ready() -> void:
		pass
	func save() -> void:
		saves += 1

var failed := 0
func check(label: String, ok: bool) -> void:
	if not ok:
		failed += 1
		print("FAIL ", label)

func _ready() -> void:
	var settings := TestSettings.new()
	add_child(settings)
	settings.set_value("fullscreen", false)
	var key := InputEventKey.new()
	key.keycode = KEY_F11
	key.pressed = true
	settings._input(key)
	check("F11 enters fullscreen and persists", settings.get_value("fullscreen") and settings.saves == 1)
	key.echo = true
	settings._input(key)
	check("key repeat ignored", settings.saves == 1)
	key.echo = false
	key.pressed = false
	settings._input(key)
	check("release ignored", settings.saves == 1)
	key.pressed = true
	key.keycode = KEY_ENTER
	settings._input(key)
	check("ordinary Enter ignored", settings.saves == 1)
	key.alt_pressed = true
	settings._input(key)
	check("Alt Enter exits fullscreen", not settings.get_value("fullscreen") and settings.saves == 2)
	key.ctrl_pressed = true
	settings._input(key)
	check("unrelated modifiers ignored", settings.saves == 2)
	key.ctrl_pressed = false
	var field := LineEdit.new()
	add_child(field)
	field.grab_focus()
	settings._input(key)
	check("typing doesn't toggle display", settings.saves == 2)
	print("all good (0 checks failed)" if failed == 0 else "checks failed: %d" % failed)
	get_tree().quit(1 if failed else 0)
