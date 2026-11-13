extends Node2D

# Pixel-art ground shadow: a broad, uneven canopy footprint rather than a smooth oval.
@export_range(1.0, 80.0, 0.5) var radius_x: float = 18.0
@export_range(1.0, 40.0, 0.5) var radius_y: float = 6.0
@export_range(0.0, 1.0, 0.01) var alpha: float = 0.26
@export var shadow_color: Color = Color(0.075, 0.09, 0.075, 1.0)

# Hand-shaped stepped contour. Uneven lobes keep the edge crisp and organic
# at the game's  pixel scale; points are scaled to each tree's footprint.
func _draw() -> void:
	# GDScript tidak mengizinkan PackedVector2Array sebagai const.
	# Simpan koordinat kontur sebagai Array lokal lalu bentuk polygon saat draw.
	var footprint: Array[Vector2] = [
		Vector2(-0.98, -0.02), Vector2(-0.91, -0.38),
		Vector2(-0.76, -0.48), Vector2(-0.65, -0.72),
		Vector2(-0.43, -0.68), Vector2(-0.30, -0.92),
		Vector2(-0.08, -0.78), Vector2(0.12, -0.88),
		Vector2(0.30, -0.68), Vector2(0.55, -0.72),
		Vector2(0.67, -0.48), Vector2(0.88, -0.43),
		Vector2(0.98, -0.08), Vector2(0.90, 0.28),
		Vector2(0.73, 0.38), Vector2(0.59, 0.70),
		Vector2(0.35, 0.62), Vector2(0.16, 0.90),
		Vector2(-0.06, 0.76), Vector2(-0.29, 0.88),
		Vector2(-0.46, 0.64), Vector2(-0.70, 0.68),
		Vector2(-0.78, 0.42), Vector2(-0.95, 0.30)
	]
	var points := PackedVector2Array()
	for p in footprint:
		points.append(Vector2(round(p.x * radius_x), round(p.y * radius_y)))

	# Main canopy shadow, with a slightly denser center for contact/depth.
	draw_colored_polygon(points, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha))

	var core := PackedVector2Array()
	for p in footprint:
		core.append(Vector2(round(p.x * radius_x * 0.70), round(p.y * radius_y * 0.62 + 1.0)))
	draw_colored_polygon(core, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha * 0.30))

	# Small trunk-contact patch anchors the shadow to the base of the tree.
	var contact := PackedVector2Array([
		Vector2(-3, -1), Vector2(-2, -2), Vector2(2, -2),
		Vector2(4, -1), Vector2(3, 1), Vector2(-3, 1)
	])
	draw_colored_polygon(contact, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha * 0.55))
	var points := PackedVector2Array()
	for p in FOOTPRINT:
		points.append(Vector2(round(p.x * radius_x), round(p.y * radius_y)))

	# Main canopy shadow, with a slightly denser center for contact/depth.
	draw_colored_polygon(points, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha))

	var core := PackedVector2Array()
	for p in FOOTPRINT:
		core.append(Vector2(round(p.x * radius_x * 0.70), round(p.y * radius_y * 0.62 + 1.0)))
	draw_colored_polygon(core, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha * 0.30))

	# Small trunk-contact patch anchors the shadow to the base of the tree.
	var contact := PackedVector2Array([
		Vector2(-3, -1), Vector2(-2, -2), Vector2(2, -2),
		Vector2(4, -1), Vector2(3, 1), Vector2(-3, 1)
	])
	draw_colored_polygon(contact, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha * 0.55))

func set_shadow_size(rx: float, ry: float) -> void:
	radius_x = maxf(1.0, rx)
	radius_y = maxf(1.0, ry)
	queue_redraw()
