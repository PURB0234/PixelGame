extends Node2D

@export var radius_x: float = 18.0
@export var radius_y: float = 7.0
@export var alpha: float = 0.25

func _draw() -> void:
	var color = Color(0.0, 0.0, 0.0, alpha)
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 32
	for i in range(steps):
		var angle = (float(i) / steps) * TAU
		var jitter = randf_range(-0.6, 10.0)
		var rx = radius_x + jitter
		var ry = radius_y + jitter * 0.4
		pts.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_polygon(pts, PackedColorArray([color]))
