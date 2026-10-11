extends Node3D

const Style := preload("res://DioramaStyle.gd")
var failures := 0

func check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _ready() -> void:
	Settings.one_to_one_only = false
	Settings.set_value("mode", "user")
	Settings.set_value("qol_tiles3d", true)
	Settings.set_value("qol_cameras", true)
	Settings.set_value("visual_style", "diorama")
	var rig = load("res://CameraRig.gd").new()
	add_child(rig)
	rig.setup(self, null, null)
	rig._mode = rig.CamMode.COMPASS
	var vp := get_viewport().get_visible_rect().size
	var hole := Rect2(Vector2(0, vp.y * 0.1), Vector2(vp.x * 0.75, vp.y * 0.8))
	rig._play_hole = hole
	rig._update_camera(0.0)
	var focus: Vector3 = rig._player + Vector3(0, rig.look_h(), 0)
	check("focus projects into play area", rig._cam.unproject_position(focus).distance_to(hole.get_center()) < 1.0)
	check("distant art stays sharp", not rig._cam.attributes.dof_blur_far_enabled)
	# Resizing the sidebar must keep centering correct without touching saved pan.
	hole = Rect2(Vector2(vp.x * 0.03, vp.y * 0.15), Vector2(vp.x * 0.55, vp.y * 0.7))
	rig._play_hole = hole
	rig._update_camera(0.0)
	check("asymmetric resized play area", rig._cam.unproject_position(focus).distance_to(hole.get_center()) < 1.0)
	rig._mode = rig.CamMode.FIRST_PERSON
	rig._update_camera(0.0)
	check("first person keeps its literal eye", is_zero_approx(rig._cam.h_offset) and is_zero_approx(rig._cam.v_offset))
	Settings.set_value("visual_style", "original")
	rig._mode = rig.CamMode.COMPASS
	rig._update_camera(0.0)
	check("original recenters whole window", rig._cam.unproject_position(focus).distance_to(vp * 0.5) < 1.0)
	check("original depth of field restored", rig._cam.attributes.dof_blur_far_enabled)
	var env := Environment.new()
	Style.apply_environment(env, true)
	check("contact shading enabled", env.ssao_enabled)
	Style.apply_environment(env, false)
	check("original lighting restored", not env.ssao_enabled and is_equal_approx(env.ambient_light_energy, 0.72))
	Settings.set_value("visual_style", "diorama")
	Settings.set_value("mode", "1to1")
	check("parity bypasses presentation", not Style.enabled())
	Settings.set_value("mode", "user")
	Settings.set_value("qol_tiles3d", false)
	check("flat tiles bypass presentation", not Style.enabled())
	if failures == 0:
		print("all good (0 checks failed)")
	else:
		print("checks failed: ", failures)
	get_tree().quit(1 if failures else 0)
