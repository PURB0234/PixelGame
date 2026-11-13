@tool
extends Node2D

enum WaterType {
	TERATAI_SINGLE = 0,
	TERATAI_FLOWER = 1,
	TERATAI_CLUSTER = 2,
	RIPPLE_1 = 3,
	RIPPLE_2 = 4,
	RIPPLE_3 = 5
}

const TEXTURES: Dictionary = {
	WaterType.TERATAI_SINGLE: preload("res://graphics/objects/stardew_water/teratai_single.png"),
	WaterType.TERATAI_FLOWER: preload("res://graphics/objects/stardew_water/teratai_flower.png"),
	WaterType.TERATAI_CLUSTER: preload("res://graphics/objects/stardew_water/teratai_cluster.png"),
	WaterType.RIPPLE_1: preload("res://graphics/objects/stardew_water/ripple_1.png"),
	WaterType.RIPPLE_2: preload("res://graphics/objects/stardew_water/ripple_2.png"),
	WaterType.RIPPLE_3: preload("res://graphics/objects/stardew_water/ripple_3.png"),
}

@export var type: WaterType = WaterType.TERATAI_FLOWER:
	set(value):
		type = value
		_update_visual()

@export var wave_float: bool = true
@export var float_speed: float = 1.6
@export var float_height: float = 0.7

var time_offset: float = 0.0

func _ready() -> void:
	time_offset = randf_range(0.0, 10.0)
	_update_visual()

func _update_visual() -> void:
	if has_node("Sprite2D"):
		$Sprite2D.texture = TEXTURES.get(type, TEXTURES[WaterType.TERATAI_FLOWER])

func _process(_delta: float) -> void:
	if not wave_float or not has_node("Sprite2D"):
		return
	var t: float = (Time.get_ticks_msec() / 1000.0) * float_speed + time_offset
	var sprite: Sprite2D = $Sprite2D
	if type in [WaterType.TERATAI_SINGLE, WaterType.TERATAI_FLOWER, WaterType.TERATAI_CLUSTER]:
		sprite.position.y = sin(t) * float_height
	else:
		# Ripple decals gently pulse without bobbing away from their water surface.
		var pulse: float = 1.0 + (sin(t * 1.35) * 0.035)
		sprite.scale = Vector2.ONE * pulse
