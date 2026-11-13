extends StaticBody2D

enum RockType {STONE, COPPER, IRON, GOLD}
signal broken(pos: Vector2)

const ROCK_TEXTURES = {
	RockType.STONE: preload("res://graphics/objects/mining/rock_stone.png"),
	RockType.COPPER: preload("res://graphics/objects/mining/rock_copper.png"),
	RockType.IRON: preload("res://graphics/objects/mining/rock_iron.png"),
	RockType.GOLD: preload("res://graphics/objects/mining/rock_gold.png"),
}

const CRACK_1 = preload("res://graphics/objects/mining/crack_1.png")
const CRACK_2 = preload("res://graphics/objects/mining/crack_2.png")
const DEBRIS_TEX = preload("res://graphics/objects/mining/debris_1.png")
const SFX_HIT = preload("res://audio/pickaxe.wav")
const SFX_BREAK = preload("res://audio/rock_break.wav")

@export var rock_type: RockType = RockType.STONE:
	set(value):
		rock_type = value
		_update_visual()

var health: int = 2
var max_health: int = 2
var is_broken: bool = false
var color_tween: Tween

func _ready() -> void:
	add_to_group("Objects")
	add_to_group("Pickaxe_able")
	_init_health()
	_update_visual()

func _init_health() -> void:
	match rock_type:
		RockType.STONE:
			max_health = 2
		RockType.COPPER:
			max_health = 3
		RockType.IRON:
			max_health = 4
		RockType.GOLD:
			max_health = 5
	health = max_health

func _update_visual() -> void:
	if not is_inside_tree() or not has_node("Sprite2D"):
		return
	var sprite: Sprite2D = get_node("Sprite2D")
	sprite.texture = ROCK_TEXTURES.get(rock_type, ROCK_TEXTURES[RockType.STONE])
	sprite.offset = Vector2(0, -8)

func hit(tool: Enum.Tool, dir: Vector2) -> void:
	if tool != Enum.Tool.PICKAXE or is_broken:
		return

	_play_sound(SFX_HIT, -2.0)
	health -= 1

	var hit_sign: float = 1.0 if dir.x >= 0 else -1.0
	var sprite: Sprite2D = get_node("Sprite2D")

	if color_tween and color_tween.is_valid():
		color_tween.kill()
	color_tween = create_tween()
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	color_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)

	var tween_shake = create_tween()
	tween_shake.tween_property(sprite, "position:x", 2.0 * hit_sign, 0.03)
	tween_shake.tween_property(sprite, "position:x", -2.0 * hit_sign, 0.03)
	tween_shake.tween_property(sprite, "position:x", 0.0, 0.03)

	_update_cracks()
	_spawn_particles(hit_sign, 4)

	if health <= 0:
		is_broken = true
		_play_sound(SFX_BREAK, 0.0)
		_give_rewards()
		_spawn_particles(hit_sign, 10)
		broken.emit(global_position)
		queue_free()

func _update_cracks() -> void:
	if not has_node("CrackSprite"):
		return
	var crack_node: Sprite2D = get_node("CrackSprite")
	var damage_ratio: float = 1.0 - (float(health) / float(max_health))
	if damage_ratio >= 0.65:
		crack_node.texture = CRACK_2
		crack_node.visible = true
	elif damage_ratio >= 0.3:
		crack_node.texture = CRACK_1
		crack_node.visible = true
	else:
		crack_node.visible = false

func _give_rewards() -> void:
	match rock_type:
		RockType.STONE:
			Data.ITEMS_AMOUNT[Enum.Item.STONE] += randi_range(2, 3)
		RockType.COPPER:
			Data.ITEMS_AMOUNT[Enum.Item.COPPER_ORE] += randi_range(1, 2)
			Data.ITEMS_AMOUNT[Enum.Item.STONE] += 1
		RockType.IRON:
			Data.ITEMS_AMOUNT[Enum.Item.IRON_ORE] += randi_range(1, 2)
			Data.ITEMS_AMOUNT[Enum.Item.STONE] += 1
		RockType.GOLD:
			Data.ITEMS_AMOUNT[Enum.Item.GOLD_ORE] += randi_range(1, 2)
			Data.ITEMS_AMOUNT[Enum.Item.STONE] += 1

func _spawn_particles(hit_sign: float, count: int) -> void:
	var p = CPUParticles2D.new()
	p.texture = DEBRIS_TEX
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = count
	p.lifetime = 0.4
	p.position = Vector2(0, -6)
	p.direction = Vector2(hit_sign * 0.8, -0.6)
	p.spread = 45.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	get_parent().add_child(p)
	p.restart()
	get_tree().create_timer(0.5).timeout.connect(p.queue_free)

func _play_sound(stream: AudioStream, vol_db: float) -> void:
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = vol_db
	player.global_position = global_position
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
