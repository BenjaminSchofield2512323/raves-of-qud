extends Node3D

class FixtureRenderer extends ZoneRenderer:
	var ew := true
	var fixture_texture: ImageTexture
	func _door_model(_tile: String) -> Dictionary:
		return {"w":16,"h":24,"fy0":0,"fy1":23,"fx0":1,"fx1":14,
			"lx0":5,"lx1":10,"ly0":5,"ly1":22,"hinge_hi":false,
			"frame_boxes":[[1,3,0,23],[12,14,0,23],[4,11,0,3]],
			"leaf_boxes":[[5,10,5,22]]}
	func _colored_tex(_tile: String, _main: String, _detail: String, _fill := Fill.NONE) -> ImageTexture:
		return fixture_texture
	func _door_span_ew(_x: int, _y: int) -> bool:
		return ew

var failed := 0
func check(label: String, ok: bool) -> void:
	if not ok:
		failed += 1
		print("FAIL ", label)

func place(r: FixtureRenderer, closed: bool, light: float, x := 3) -> Array:
	var bank := Node3D.new()
	r.add_child(bank)
	r._bank = bank
	check("door builds", r._place_door_voxel("door.bmp", "&y", "k", x, 4, 0, light, closed))
	return [bank.get_child(0), bank.get_child(1), bank.get_child(2)]

func _ready() -> void:
	var r := FixtureRenderer.new()
	add_child(r)
	var im := Image.create(16,24,false,Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	r.fixture_texture = ImageTexture.create_from_image(im)
	var first := place(r, true, 1.0)
	var changed := place(r, false, 0.3, 8)
	check("frame reused", first[1].mesh == changed[1].mesh)
	check("cap reused", first[0].mesh == changed[0].mesh)
	check("leaf reused", first[2].get_child(0).mesh == changed[2].get_child(0).mesh)
	check("door still opens", is_zero_approx(first[2].rotation.y) and not is_zero_approx(changed[2].rotation.y))
	check("position still updates", changed[1].position.x == 8)
	check("lighting remains per instance", is_equal_approx(changed[1].material_override.albedo_color.r, 0.3) and is_equal_approx(first[1].material_override.albedo_color.r, 1.0))
	r._derived_door_meshes.clear()
	var fresh := place(r, false, 0.3, 8)
	for i in 2:
		check("cached surface matches rebuilt", changed[i].mesh.surface_get_arrays(0) == fresh[i].mesh.surface_get_arrays(0))
	check("cached leaf matches rebuilt", changed[2].get_child(0).mesh.surface_get_arrays(0) == fresh[2].get_child(0).mesh.surface_get_arrays(0))
	r.ew = false
	var turned := place(r, false, 0.3)
	check("orientation has own mesh", turned[1].mesh != fresh[1].mesh)
	var tile := "Assets_Content_Textures_Tiles_sw_axle_2_EW.bmp"
	check("family normalization", r.tile_family(tile) == "sw_axle")
	r._overrides["sw_axle"] = "wall"
	check("warm family cache honors new overrides", r._is_prism({"tile":tile}))
	r._overrides["sw_axle"] = "billboard"
	check("warm family cache honors changed overrides", not r._is_prism({"tile":tile}))
	print("all good (0 checks failed)" if failed == 0 else "checks failed: %d" % failed)
	get_tree().quit(1 if failed else 0)
