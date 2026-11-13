@tool
extends Node2D

const FLORA_TEXTURES: Array[Texture2D] = [
	preload("res://graphics/objects/grass_assets/06_grass_ground_tile.png"),
	preload("res://graphics/objects/grass_assets/07_grass_clump.png"),
	preload("res://graphics/objects/grass_assets/08_grass_clump.png"),
	preload("res://graphics/objects/grass_assets/09_white_flower_grass.png"),
	preload("res://graphics/objects/grass_assets/10_berry_grass.png"),
	preload("res://graphics/objects/grass_assets/11_leaf_bush.png"),
	preload("res://graphics/objects/grass_assets/12_broad_leaf_plant.png"),
	preload("res://graphics/objects/grass_assets/13_purple_flower_grass.png"),
	preload("res://graphics/objects/grass_assets/14_white_flower_bush.png"),
	preload("res://graphics/objects/grass_assets/15_leaf_bush.png"),
	preload("res://graphics/objects/grass_assets/16_pink_flower_bush.png"),
	preload("res://graphics/objects/grass_assets/17_orange_flower_bush.png"),
	preload("res://graphics/objects/grass_assets/18_small_leaf_plant.png"),
	preload("res://graphics/objects/grass_assets/19_white_flower_patch.png"),
	preload("res://graphics/objects/grass_assets/20_round_leaf_bush.png"),
	preload("res://graphics/objects/grass_assets/21_leafy_grass_clump.png"),
	preload("res://graphics/objects/grass_assets/26_small_rock_grass.png"),
	preload("res://graphics/objects/grass_assets/27_leafy_plant.png"),
]

@export var random: bool = false
@export_range(0, 27, 1) var variant: int = 6:
	set(value):
		variant = clampi(value, 0, FLORA_TEXTURES.size() - 1)
		_rebuild_sprites()

@export var dense: bool = false
@export_range(2, 12, 1) var dense_count: int = 3
@export var spread: float = 18.0

@export var wind_sway: bool = true
@export var sway_speed: float = 2.0
@export var sway_strength: float = 0.05

var _sprites: Array[Sprite2D] = []
var _time_offsets: Array[float] = []
var _squish_tween: Tween = null

func _ready() -> void:
	if random:
		variant = randi() % FLORA_TEXTURES.size()
	_rebuild_sprites()
	_setup_trigger_area()

func _rebuild_sprites() -> void:
	if not is_inside_tree():
		return
	for s in _sprites:
		if is_instance_valid(s):
			s.queue_free()
	_sprites.clear()
	_time_offsets.clear()
	var count = dense_count if dense else 1
	var tex = FLORA_TEXTURES[variant]
	for i in range(count):
		var spr = Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(0.12, 0.12)
		if i == 0:
			spr.offset = Vector2(0, -40)
		else:
			spr.offset = Vector2(
				randf_range(-spread, spread),
				randf_range(-40.0 - spread * 0.3, -40.0 + spread * 0.3)
			)
		var scale_var = randf_range(0.9, 1.1)
		spr.scale *= scale_var
		spr.flip_h = randf() > 0.5
		add_child(spr)
		_sprites.append(spr)
		_time_offsets.append(randf_range(0.0, 10.0))

func _setup_trigger_area() -> void:
	if has_node("TriggerArea"):
		return
	var area = Area2D.new()
	area.name = "TriggerArea"
	area.collision_layer = 0
	area.collision_mask = 2
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_player_entered)

func _on_player_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	var dir = signf(body.global_position.x - global_position.x)
	if dir == 0.0:
		dir = 1.0
	_play_squish(dir)

func _play_squish(dir: float) -> void:
	if _squish_tween and _squish_tween.is_valid():
		_squish_tween.kill()
	_squish_tween = create_tween()
	for spr in _sprites:
		if not is_instance_valid(spr):
			continue
		_squish_tween.parallel().tween_property(spr, "skew", 0.25 * dir, 0.08)
		_squish_tween.parallel().tween_property(spr, "scale:y", spr.scale.y * 0.85, 0.08)
	_squish_tween.tween_interval(0.05)
	for spr in _sprites:
		if not is_instance_valid(spr):
			continue
		_squish_tween.parallel().tween_property(spr, "skew", -0.1 * dir, 0.1)
		_squish_tween.parallel().tween_property(spr, "scale:y", spr.scale.y, 0.1)
	_squish_tween.tween_interval(0.03)
	for spr in _sprites:
		if not is_instance_valid(spr):
			continue
		_squish_tween.parallel().tween_property(spr, "skew", 0.0, 0.12)

func _process(_delta: float) -> void:
	if not wind_sway:
		return
	for i in range(_sprites.size()):
		if not is_instance_valid(_sprites[i]):
			continue
		var t = (Time.get_ticks_msec() / 1000.0) * sway_speed + _time_offsets[i]
		if _squish_tween == null or not _squish_tween.is_valid():
			_sprites[i].skew = sin(t) * sway_strength
