extends StaticBody2D

@export_file("*.tscn") var target_scene: String = "res://scenes/levels/level.tscn"

var is_transitioning: bool = false

func _ready() -> void:
	add_to_group("Objects")
	if has_node("ExitArea"):
		var exit: Area2D = get_node("ExitArea")
		exit.body_entered.connect(_on_exit_entered)
		exit.area_entered.connect(_on_area_entered)

func _on_exit_entered(body: Node2D) -> void:
	if is_transitioning:
		return
	if body.name == "Player" or body.is_in_group("Player"):
		is_transitioning = true
		_transition_to_level()

func _on_area_entered(area: Area2D) -> void:
	if is_transitioning:
		return
	var parent_node = area.get_parent()
	if parent_node and (parent_node.name == "Player" or parent_node.is_in_group("Player")):
		is_transitioning = true
		_transition_to_level()

func _transition_to_level() -> void:
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)
