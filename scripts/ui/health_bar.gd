extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel

func _ready() -> void:
	update_health(Data.PLAYER_MAX_HEALTH, Data.PLAYER_MAX_HEALTH)

func update_health(current_health: int, max_health: int) -> void:
	if not is_node_ready():
		await ready
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "HP %d / %d" % [current_health, max_health]
