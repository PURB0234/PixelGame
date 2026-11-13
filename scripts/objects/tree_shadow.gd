extends Node2D

# Low, broad, foliage-shaped shadow painted in crisp pixel-art clusters.
@export_range(1.0, 90.0, 0.5) var radius_x: float = 24.0
@export_range(1.0, 50.0, 0.5) var radius_y: float = 9.0
@export_range(0.0, 1.0, 0.01) var alpha: float = 0.34
@export var shadow_color: Color = Color(0.035, 0.12, 0.065, 1.0)

func _draw() -> void:
	# Broad irregular footprint: several connected foliage lobes, not an oval.
	var silhouette := PackedVector2Array([
		Vector2(-0.98, 0.02), Vector2(-0.91, -0.36),
		Vector2(-0.76, -0.48), Vector2(-0.64, -0.78),
		Vector2(-0.42, -0.70), Vector2(-0.28, -0.91),
		Vector2(-0.08, -0.79), Vector2(0.12, -0.94),
		Vector2(0.31, -0.73), Vector2(0.53, -0.78),
		Vector2(0.69, -0.50), Vector2(0.88, -0.38),
		Vector2(0.99, -0.04), Vector2(0.91, 0.32),
		Vector2(0.76, 0.43), Vector2(0.61, 0.76),
		Vector2(0.36, 0.66), Vector2(0.17, 0.94),
		Vector2(-0.06, 0.78), Vector2(-0.29, 0.91),
		Vector2(-0.47, 0.68), Vector2(-0.70, 0.73),
		Vector2(-0.81, 0.43), Vector2(-0.96, 0.31)
	])
	var points := PackedVector2Array()
	for p in silhouette:
		points.append(Vector2(round(p.x * radius_x), round(p.y * radius_y)))
	draw_colored_polygon(points, _shadow_tint(alpha))

	# Darker, broken foliage clusters around the outside create the mottled edge
	# seen in the reference, while keeping the middle free of a dark oval core.
	_draw_lobe(Vector2(-0.66, -0.08), 0.35, 0.63, alpha * 0.42)
	_draw_lobe(Vector2(-0.30, -0.22), 0.34, 0.55, alpha * 0.30)
	_draw_lobe(Vector2(0.12, -0.18), 0.38, 0.58, alpha * 0.30)
	_draw_lobe(Vector2(0.63, -0.06), 0.34, 0.62, alpha * 0.42)
	_draw_lobe(Vector2(-0.52, 0.28), 0.40, 0.48, alpha * 0.32)
	_draw_lobe(Vector2(0.02, 0.30), 0.42, 0.48, alpha * 0.26)
	_draw_lobe(Vector2(0.56, 0.28), 0.38, 0.48, alpha * 0.34)

	# Small square flecks make the edge read as pixels rather than a smooth blur.
	var flecks := [
		Vector2(-0.88, -0.55), Vector2(-0.72, 0.62), Vector2(-0.48, -0.88),
		Vector2(-0.18, 0.82), Vector2(0.12, -0.82), Vector2(0.43, 0.78),
		Vector2(0.72, -0.62), Vector2(0.88, 0.40), Vector2(-0.98, 0.18)
	]
	for p in flecks:
		var pos := Vector2(round(p.x * radius_x), round(p.y * radius_y))
		draw_rect(Rect2(pos, Vector2(2.0, 2.0)), _shadow_tint(alpha * 0.52))

	# Tight contact shadow directly under the trunk; intentionally subtle.
	draw_rect(Rect2(Vector2(-4.0, -1.0), Vector2(8.0, 3.0)), _shadow_tint(alpha * 0.55))

func _draw_lobe(center: Vector2, width_ratio: float, height_ratio: float, opacity: float) -> void:
	var lobe := PackedVector2Array()
	var radii := [
		Vector2(-1.0, 0.0), Vector2(-0.72, -0.72),
		Vector2(-0.12, -1.0), Vector2(0.62, -0.78),
		Vector2(1.0, -0.12), Vector2(0.78, 0.62),
		Vector2(0.10, 1.0), Vector2(-0.68, 0.70)
	]
	for p in radii:
		var x: float = (center.x + p.x * width_ratio * 0.5) * radius_x
		var y: float = (center.y + p.y * height_ratio * 0.5) * radius_y
		lobe.append(Vector2(round(x), round(y)))
	draw_colored_polygon(lobe, _shadow_tint(opacity))

func _shadow_tint(opacity: float) -> Color:
	return Color(shadow_color.r, shadow_color.g, shadow_color.b, opacity)

func set_shadow_size(rx: float, ry: float) -> void:
	radius_x = maxf(1.0, rx)
	radius_y = maxf(1.0, ry)
	queue_redraw()
