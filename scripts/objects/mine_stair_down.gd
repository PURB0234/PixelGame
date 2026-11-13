extends Area2D

signal stair_entered

var triggered: bool = false

func _ready() -> void:
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
		if triggered:
				return
		if body.name == "Player" or body.is_in_group("Player"):
				triggered = true
				stair_entered.emit()
