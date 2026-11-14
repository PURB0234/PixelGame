@tool
extends Node2D

const FLORA_TEXTURES: Array[Texture2D] = [
		preload("res://graphics/objects/harvest_flora/01_white_daisy.png"),
		preload("res://graphics/objects/harvest_flora/02_red_tulip.png"),
		preload("res://graphics/objects/harvest_flora/03_yellow_dandelion.png"),
		preload("res://graphics/objects/harvest_flora/04_purple_lavender.png"),
		preload("res://graphics/objects/harvest_flora/05_pink_cosmos.png"),
		preload("res://graphics/objects/harvest_flora/06_blue_hydrangea.png"),
		preload("res://graphics/objects/harvest_flora/07_four_leaf_clover.png"),
		preload("res://graphics/objects/harvest_flora/08_wild_grass_short.png"),
		preload("res://graphics/objects/harvest_flora/09_wild_grass_tall.png"),
		preload("res://graphics/objects/harvest_flora/10_round_bush.png"),
		preload("res://graphics/objects/harvest_flora/11_berry_bush.png"),
		preload("res://graphics/objects/harvest_flora/12_fern_sprout.png"),
		preload("res://graphics/objects/harvest_flora/13_autumn_leaf_patch.png"),
		preload("res://graphics/objects/harvest_flora/14_wild_sprout.png"),
		preload("res://graphics/objects/harvest_flora/15_sunflower_mini.png"),
		preload("res://graphics/objects/harvest_flora/16_golden_wheat_grass.png"),
		preload("res://graphics/objects/harvest_flora/17_succulent_plant.png"),
		preload("res://graphics/objects/harvest_flora/18_flower_cluster.png"),
]

@export var random: bool = false
@export_range(0, 17, 1) var variant: int = 0:
		set(value):
				variant = clampi(value, 0, FLORA_TEXTURES.size() - 1)
				_rebuild_sprites()

@export var dense: bool = false
@export_range(2, 8, 1) var dense_count: int = 3
@export_range(4.0, 16.0, 1.0) var spread: float = 8.0

@export var wind_sway: bool = true
@export var sway_speed: float = 1.8
@export var sway_strength: float = 0.035

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
		for sprite in _sprites:
				if is_instance_valid(sprite):
						sprite.queue_free()
		_sprites.clear()
		_time_offsets.clear()

		var count: int = dense_count if dense else 1
		var used_variants: Array[int] = []
		for i in range(count):
				var chosen_variant: int = variant
				if dense:
						var candidates: Array[int] = []
						for candidate in range(FLORA_TEXTURES.size()):
								if i == 0 or not used_variants.has(candidate):
										candidates.append(candidate)
						chosen_variant = candidates.pick_random() if not candidates.is_empty() else randi_range(0, FLORA_TEXTURES.size() - 1)
						used_variants.append(chosen_variant)

				var sprite := Sprite2D.new()
				sprite.texture = FLORA_TEXTURES[chosen_variant]
				sprite.scale = Vector2.ONE
				if i == 0:
						sprite.offset = Vector2(0, -16)
				else:
						sprite.offset = Vector2(
								randf_range(-spread, spread),
								-16.0 + randf_range(-spread * 0.25, spread * 0.25)
						)
				sprite.flip_h = randf() > 0.5
				sprite.z_index = i
				add_child(sprite)
				_sprites.append(sprite)
				_time_offsets.append(randf_range(0.0, 10.0))

func _setup_trigger_area() -> void:
		if has_node("TriggerArea"):
				return
		var area := Area2D.new()
		area.name = "TriggerArea"
		area.collision_layer = 0
		area.collision_mask = 2
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 10.0
		shape.shape = circle
		area.add_child(shape)
		add_child(area)
		area.body_entered.connect(_on_player_entered)

func _on_player_entered(body: Node2D) -> void:
		if not body.is_in_group("Player"):
				return
		var direction: float = signf(body.global_position.x - global_position.x)
		if direction == 0.0:
				direction = 1.0
		_play_squish(direction)

func _play_squish(direction: float) -> void:
		if _squish_tween and _squish_tween.is_valid():
				_squish_tween.kill()
		_squish_tween = create_tween()
		for sprite in _sprites:
				if not is_instance_valid(sprite):
						continue
				_squish_tween.parallel().tween_property(sprite, "skew", 0.18 * direction, 0.08)
				_squish_tween.parallel().tween_property(sprite, "scale:y", sprite.scale.y * 0.85, 0.08)
		_squish_tween.tween_interval(0.05)
		for sprite in _sprites:
				if not is_instance_valid(sprite):
						continue
				_squish_tween.parallel().tween_property(sprite, "skew", -0.08 * direction, 0.1)
				_squish_tween.parallel().tween_property(sprite, "scale:y", sprite.scale.y, 0.1)
		_squish_tween.tween_interval(0.03)
		for sprite in _sprites:
				if not is_instance_valid(sprite):
						continue
				_squish_tween.parallel().tween_property(sprite, "skew", 0.0, 0.12)

func _process(_delta: float) -> void:
		if not wind_sway:
				return
		for i in range(_sprites.size()):
				if not is_instance_valid(_sprites[i]):
						continue
				var t: float = (Time.get_ticks_msec() / 1000.0) * sway_speed + _time_offsets[i]
				if _squish_tween == null or not _squish_tween.is_valid():
						_sprites[i].skew = sin(t) * sway_strength
