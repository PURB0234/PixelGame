extends Node2D

const MINE_ROCK_SCENE: PackedScene = preload("res://scenes/objects/mine_rock.tscn")
const STAIR_DOWN_SCENE: PackedScene = preload("res://scenes/objects/mine_stair_down.tscn")

@onready var player: CharacterBody2D = get_node_or_null("Objects/Player")
@onready var objects: Node2D = get_node_or_null("Objects")
@onready var wall_layer: TileMapLayer = get_node_or_null("Layers/CaveWallLayer")
@onready var floor_label: Label = get_node_or_null("Overlay/FloorPanel/MarginContainer/FloorLabel")

var current_floor: int = 1
var has_stair: bool = false

func _ready() -> void:
		if player:
				player.tool_use.connect(_on_player_tool_use)
				player.do_action.connect(_on_player_do_action)
		spawn_rocks(32)

func spawn_rocks(amount: int = 32) -> void:
		if not objects:
				return
		has_stair = false
		for node in get_tree().get_nodes_in_group("Pickaxe_able"):
				node.queue_free()
		for child in objects.get_children():
				if child.is_in_group("MineStair"):
						child.queue_free()
		var spawned: int = 0
		var occupied: Array[Vector2i] = []
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		var attempts: int = 0
		while spawned < amount and attempts < 300:
				attempts += 1
				var gx: int = rng.randi_range(2, 27)
				var gy: int = rng.randi_range(4, 19)
				var cell: Vector2i = Vector2i(gx, gy)
				if cell in occupied:
						continue
				if gx >= 13 and gx <= 17 and gy <= 7:
						continue
				if wall_layer and wall_layer.get_cell_source_id(cell) != -1:
						continue
				occupied.append(cell)
				var rock = MINE_ROCK_SCENE.instantiate()
				var roll: float = rng.randf()
				var gold_chance: float = clampf((current_floor - 2) * 0.04, 0.0, 0.20)
				var iron_chance: float = clampf((current_floor - 1) * 0.05, 0.05, 0.30)
				var copper_chance: float = 0.25
				if roll < gold_chance:
						rock.rock_type = 3
				elif roll < gold_chance + iron_chance:
						rock.rock_type = 2
				elif roll < gold_chance + iron_chance + copper_chance:
						rock.rock_type = 1
				else:
						rock.rock_type = 0
				rock.position = Vector2(gx * 16 + 8, gy * 16 + 16)
				rock.broken.connect(_on_rock_broken)
				objects.add_child(rock)
				spawned += 1

func _on_rock_broken(pos: Vector2) -> void:
		if has_stair:
				return
		var remaining: int = get_tree().get_nodes_in_group("Pickaxe_able").size()
		if remaining <= 1 or randf() < 0.2:
				has_stair = true
				var stair = STAIR_DOWN_SCENE.instantiate()
				stair.position = pos
				stair.add_to_group("MineStair")
				objects.add_child(stair)
				stair.stair_entered.connect(_on_stair_entered)

func _on_stair_entered() -> void:
		current_floor += 1
		if floor_label:
				floor_label.text = "Lantai " + str(current_floor)
		if player:
				player.position = Vector2(240, 88)
		spawn_rocks(32)

func _on_player_tool_use(tool: Enum.Tool, pos: Vector2, dir: Vector2) -> void:
		match tool:
				Enum.Tool.PICKAXE:
						for rock in get_tree().get_nodes_in_group("Pickaxe_able"):
								var diff: Vector2 = rock.global_position - pos
								if diff.length() < 30.0:
										var norm: Vector2 = diff.normalized()
										if dir.dot(norm) > 0.35:
												rock.hit(tool, dir)
				Enum.Tool.SWORD:
						for enemy in get_tree().get_nodes_in_group("Sword_able"):
								var diff: Vector2 = enemy.global_position - pos
								if diff.length() < 28.0:
										enemy.hit(tool, dir)

func _on_player_do_action(anim_tree: AnimationTree, property: StringName, _tool: int, _pos: Vector2, _dir: Vector2) -> void:
		anim_tree.set(property, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
