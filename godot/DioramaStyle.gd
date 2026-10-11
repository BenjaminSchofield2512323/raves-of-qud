extends RefCounted

## Optional presentation only. Qud's visibility, cells and simulation stay authoritative.
static func enabled() -> bool:
	return str(Settings.get_value("visual_style", "original")) == "diorama" \
		and not Settings.qud_shape("tiles3d")

static func apply_environment(env: Environment, on: bool) -> void:
	# Local creases/contact shading give the carved walls depth without blurring
	# the pixel art or using bloom. These properties are supported by Forward+.
	env.ssao_enabled = on
	env.ssao_radius = 0.55
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	env.ambient_light_color = Color(0.80, 0.82, 0.85) if on else Color(0.72, 0.72, 0.74)
	env.ambient_light_energy = 0.80 if on else 0.72

## World-units of camera offset needed to project the focus into the play area.
## Camera3D offsets translate along its local axes; screen Y points down.
static func focus_offset(viewport: Vector2, hole: Rect2, distance: float,
		vertical_fov: float) -> Vector2:
	if viewport.y <= 0.0 or hole.size.x <= 0.0 or hole.size.y <= 0.0:
		return Vector2.ZERO
	var units_per_pixel := 2.0 * maxf(distance, 0.01) * tan(deg_to_rad(vertical_fov) * 0.5) / viewport.y
	var delta := viewport * 0.5 - hole.get_center()
	return Vector2(delta.x, -delta.y) * units_per_pixel
