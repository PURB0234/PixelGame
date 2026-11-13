extends Node2D

@export_range(1.0, 80.0, 0.5) var radius_x: float = 18.0
@export_range(1.0, 40.0, 0.5) var radius_y: float = 7.0
@export_range(0.0, 1.0, 0.01) var alpha: float = 0.22
@export var shadow_color: Color = Color(0.035, 0.045, 0.035, 1.0)

func _draw() -> void:
	# A stable, soft-edged ellipse: no per-frame random jitter (which caused flicker).
	var points := PackedVector2Array()
	var steps := 48
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha))

	# Layered inner ellipses soften the silhouette without a heavy outline.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.78, 0.72))
	draw_colored_polygon(points, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha * 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func set_shadow_size(rx: float, ry: float) -> void:
	radius_x = rx
	radius_y = ry
	queue_redraw()
