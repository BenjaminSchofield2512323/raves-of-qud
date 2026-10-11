extends Node3D

func _ready() -> void:
	if InputModel.diagnostics_dir() == "":
		push_error("Replay requires --headless and an absolute --diagnostics-dir= path")
		get_tree().quit(2)
		return
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--snapshot="):
			path = arg.trim_prefix("--snapshot=")
	if not FileAccess.file_exists(path):
		push_error("Snapshot file does not exist: " + path)
		get_tree().quit(2)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("cells") is Array:
		push_error("Replay requires a captured snapshot JSON containing cells")
		get_tree().quit(2)
		return
	var renderer := ZoneRenderer.new()
	add_child(renderer)
	renderer.render_snapshot(data)
	renderer._ib_finish()
	for i in 3:
		await get_tree().process_frame
		renderer.render_snapshot(data)
	Profiler.reset()
	for i in 20:
		await get_tree().process_frame
		Profiler.begin("render")
		renderer.render_snapshot(data)
		Profiler.done("render")
	var report := "HEADLESS CPU REPLAY: repeated snapshot, no gameplay or GPU timing.\n" + Profiler.report()
	print(report)
	var output := FileAccess.open(InputModel.support_dir().path_join("profile.txt"), FileAccess.WRITE)
	if output == null:
		push_error("Cannot write diagnostic profile")
		get_tree().quit(2)
		return
	output.store_string(report)
	get_tree().quit()
