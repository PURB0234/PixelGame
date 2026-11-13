extends Node2D

@export var count: int = 20
@export var spawn_area: Rect2 = Rect2(-200, -200, 600, 600)
@export var spawn_on_water: bool = false
@export var max_attempts_multiplier: int = 10

const GRASS_SCENE = preload("res://scenes/objects/grass_deco.tscn")
const WATER_SCENE = preload("res://scenes/objects/water_deco.tscn")

func _ready() -> void:
		var layer: TileMapLayer = get_node_or_null("../../Layers/WaterGrassLayer")
		if not layer and get_tree().current_scene:
				layer = get_tree().current_scene.get_node_or_null("Layers/WaterGrassLayer")

		var spawned: int = 0
		var attempts: int = 0
		var max_attempts: int = count * max_attempts_multiplier

		while spawned < count and attempts < max_attempts:
				attempts += 1
				var candidate_pos = Vector2(
						randf_range(spawn_area.position.x, spawn_area.end.x),
						randf_range(spawn_area.position.y, spawn_area.end.y)
				)

				if layer:
						var cell_coord: Vector2i = layer.local_to_map(layer.to_local(candidate_pos))
						var cell_data = layer.get_cell_tile_data(cell_coord)
						if not cell_data:
								continue
						var is_water: bool = bool(cell_data.get_custom_data("water"))
						if is_water != spawn_on_water:
								continue

				var item
				if spawn_on_water:
						item = WATER_SCENE.instantiate()
#Acak antara teratai (3) dan detail perairan (2)
						item.type = [1, 2].pick_random()
				else:
						item = GRASS_SCENE.instantiate()
						item.random = true

				item.position = candidate_pos
				add_child(item)
				spawned += 1
