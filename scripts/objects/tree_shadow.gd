extends Node2D

@export_range(1.0, 80.0, 0.5) var radius_x: float = 14.0
@export_range(1.0, 40.0, 0.5) var radius_y: float = 4.5
@export_range(0.0, 1.0, 0.01) var alpha: float = 0.16
@export var shadow_color: Color = Color(0.035, 0.045, 0.035, 1.0)

func _draw() -> void:
	# Compact ground shadow, kept close to the trunk so it cannot spill far
	# beyond smaller tree canopies. Rounded points preserve a pixel-art look.
	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		var point := Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		points.append(Vector2(round(point.x), round(point.y)))

	# Main contact shadow.
	draw_colored_polygon(points, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha))

	# A smaller, lighter core gives a little depth without a blurry/oversized halo.
	var inner_points := PackedVector2Array()
	for point in points:
		inner_points.append(Vector2(round(point.x * 0.68), round(point.y * 0.62)))
	draw_colored_polygon(inner_points, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha * 0.32))

func set_shadow_size(rx: float, ry: float) -> void:
	radius_x = maxf(1.0, rx)
	radius_y = maxf(1.0, ry)
	queue_redraw()
