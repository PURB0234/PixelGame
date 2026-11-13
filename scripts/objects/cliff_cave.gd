extends StaticBody2D

@export_file("*.tscn") var target_scene: String = "res://scenes/levels/mine_level.tscn"

var is_transitioning: bool = false
var flicker_timer: float = 0.0

func _ready() -> void:
	add_to_group("Objects")
	if has_node("DoorArea"):
		var door: Area2D = get_node("DoorArea")
		door.body_entered.connect(_on_door_entered)
		door.area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	flicker_timer += delta
	if flicker_timer >= 0.1:
		flicker_timer = 0.0
		var energy_offset = randf_range(-0.06, 0.06)
		if has_node("LightLeft"):
			get_node("LightLeft").energy = clampf(0.75 + energy_offset, 0.6, 0.9)
		if has_node("LightRight"):
			get_node("LightRight").energy = clampf(0.75 - energy_offset, 0.6, 0.9)

func _on_door_entered(body: Node2D) -> void:
	if is_transitioning:
		return
	if body.name == "Player" or body.is_in_group("Player"):
		is_transitioning = true
		_transition_to_mine()

func _on_area_entered(area: Area2D) -> void:
	if is_transitioning:
		return
	var parent_node = area.get_parent()
	if parent_node and (parent_node.name == "Player" or parent_node.is_in_group("Player")):
		is_transitioning = true
		_transition_to_mine()

func _transition_to_mine() -> void:
	if target_scene == "":
		return
	get_tree().change_scene_to_file(target_scene)
