extends StaticBody2D

const TREE_TEXTURE = preload("res://graphics/plants/oak_tree/stage_5_mature.png")
const FALL_CANOPY = preload("res://graphics/plants/oak_tree/canopy_mature.png")
const APPLE_TEXTURE = preload("res://graphics/plants/apple.png")
const LEAF_TEX = preload("res://graphics/plants/oak_tree/leaf_particle_1.png")
const LEAF_TEX2 = preload("res://graphics/plants/oak_tree/leaf_particle_2.png")
const WOOD_CHIP_TEX = preload("res://graphics/plants/oak_tree/wood_chip_particle.png")
const LOG_TEX = preload("res://graphics/plants/oak_tree/wood_log_full.png")
const SFX_FALL = preload("res://audio/falling-tree.wav")
const SFX_IMPACT = preload("res://audio/tree_impact.wav")
const SFX_CHOP = preload("res://audio/chopping-tree.wav")

const MAX_HEALTH := 3
const APPLE_MIN := 2
const APPLE_MAX := 4

var tree_health: int = MAX_HEALTH
var is_falling := false
var apples_available: int = 0
var color_tween: Tween
var shake_tween: Tween
var player_node: Node2D

@onready var tree_sprite: Sprite2D = $Sprite2D
@onready var apples_node: Node2D = $Apples
@onready var shadow: Node2D = $Shadow

func _ready() -> void:
	add_to_group("Objects")
	add_to_group("Tree")
	add_to_group("Axe_able")
	tree_sprite.texture = TREE_TEXTURE
	create_apple()
	$Stump.visible = false
	$StumpCollision.disabled = true

func _process(_delta: float) -> void:
	if player_node and not is_falling:
		var behind := player_node.global_position.y < global_position.y - 8.0 and abs(player_node.global_position.x - global_position.x) < 22.0
		var target_alpha := 0.58 if behind else 1.0
		if abs(tree_sprite.modulate.a - target_alpha) > 0.04:
			if color_tween and color_tween.is_valid():
				color_tween.kill()
			color_tween = create_tween()
			color_tween.tween_property(tree_sprite, "modulate:a", target_alpha, 0.14)
	elif not is_falling and tree_sprite.modulate.a < 0.98:
		tree_sprite.modulate.a = 1.0

func hit(tool: Enum.Tool, dir: Vector2) -> void:
	if tool != Enum.Tool.AXE or is_falling:
		return

	_play_sound(SFX_CHOP, -1.0)
	_drop_one_apple()
	tree_health -= 1
	_spawn_chop_particles(dir.x)
	_flash_and_shake(dir.x)

	if tree_health <= 0:
		remove_from_group("Tree")
		remove_from_group("Axe_able")
		$CollisionShape2D.disabled = true
		$BehindTreeArea2D.monitoring = false
		Data.ITEMS_AMOUNT[Enum.Item.WOOD] += randi_range(3, 5)
		# Remaining fruit falls with the tree.
		var remaining := apples_available
		for i in range(remaining):
			Data.ITEMS_AMOUNT[Enum.Item.APPLE] += 1
		apples_available = 0
		for apple in apples_node.get_children():
			apple.queue_free()
		$Stump.visible = true
		$StumpCollision.disabled = false
		_fall_tree(1.0 if dir.x >= 0.0 else -1.0)

func _flash_and_shake(fall_sign: float) -> void:
	if color_tween and color_tween.is_valid():
		color_tween.kill()
	tree_sprite.modulate = Color(1.65, 1.65, 1.65, 1.0)
	color_tween = create_tween()
	color_tween.tween_property(tree_sprite, "modulate", Color.WHITE, 0.16)
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	shake_tween = create_tween()
	shake_tween.tween_property(tree_sprite, "position:x", 2.5 * fall_sign, 0.045)
	shake_tween.tween_property(tree_sprite, "position:x", -2.0 * fall_sign, 0.045)
	shake_tween.tween_property(tree_sprite, "position:x", 0.0, 0.055)

func _drop_one_apple() -> void:
	if apples_available <= 0:
		return
	apples_available -= 1
	Data.ITEMS_AMOUNT[Enum.Item.APPLE] += 1
	var candidates := apples_node.get_children()
	if candidates.is_empty():
		return
	var apple: Sprite2D = candidates.pick_random()
	var tw := create_tween()
	var start := apple.position
	tw.tween_property(apple, "position", start + Vector2(randf_range(-7.0, 7.0), 8.0), 0.16)
	tw.parallel().tween_property(apple, "modulate:a", 0.0, 0.2)
	tw.tween_callback(apple.queue_free)

func create_apple() -> void:
	if not is_inside_tree() or not has_node("Apples"):
		return
	apples_available = mini(randi_range(APPLE_MIN, APPLE_MAX), MAX_HEALTH)
	for child in apples_node.get_children():
		child.queue_free()
	var markers := $AppleSpawnPositions.get_children()
	markers.shuffle()
	for i in range(apples_available):
		var apple := Sprite2D.new()
		apple.texture = APPLE_TEXTURE
		apple.position = markers[i].position
		apple.scale = Vector2(0.75, 0.75)
		apple.z_index = 3
		apples_node.add_child(apple)

func grow_day() -> void:
	if not is_falling and $Stump.visible:
		return
	if not is_falling and tree_health < MAX_HEALTH:
		tree_health += 1
	if not is_falling and apples_available == 0 and not $Stump.visible:
		create_apple()

func _spawn_chop_particles(fall_sign: float) -> void:
	var leaves := CPUParticles2D.new()
	leaves.texture = LEAF_TEX if randf() > 0.5 else LEAF_TEX2
	leaves.one_shot = true
	leaves.emitting = false
	leaves.explosiveness = 0.9
	leaves.amount = 7
	leaves.lifetime = 0.85
	leaves.direction = Vector2(fall_sign, -1.0)
	leaves.spread = 60.0
	leaves.initial_velocity_min = 28.0
	leaves.initial_velocity_max = 62.0
	leaves.gravity = Vector2(0, 120)
	leaves.position = Vector2(fall_sign * 4.0, -35.0)
	add_child(leaves)
	leaves.emitting = true
	get_tree().create_timer(1.0).timeout.connect(leaves.queue_free)

	var chips := CPUParticles2D.new()
	chips.texture = WOOD_CHIP_TEX
	chips.one_shot = true
	chips.emitting = false
	chips.explosiveness = 1.0
	chips.amount = 4
	chips.lifetime = 0.45
	chips.direction = Vector2(fall_sign, -0.25)
	chips.spread = 45.0
	chips.initial_velocity_min = 38.0
	chips.initial_velocity_max = 82.0
	chips.gravity = Vector2(0, 190)
	chips.position = Vector2(0, -9.0)
	add_child(chips)
	chips.emitting = true
	get_tree().create_timer(0.6).timeout.connect(chips.queue_free)

func _fall_tree(fall_sign: float) -> void:
	is_falling = true
	_play_sound(SFX_FALL, -2.0)
	var canopy := Sprite2D.new()
	canopy.texture = FALL_CANOPY
	canopy.scale = Vector2(0.1, 0.1)
	canopy.position = Vector2(0, -14.5)
	canopy.offset = Vector2(0, -FALL_CANOPY.get_height() / 2.0)
	add_child(canopy)
	tree_sprite.visible = false
	apples_node.visible = false
	var target_rotation := deg_to_rad(90.0 * fall_sign)
	var tw := create_tween()
	tw.tween_property(canopy, "rotation", deg_to_rad(-4.0 * fall_sign), 0.12)
	tw.tween_property(canopy, "rotation", target_rotation, 0.72).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(canopy, "rotation", target_rotation - deg_to_rad(7.0 * fall_sign), 0.08)
	tw.tween_property(canopy, "rotation", target_rotation, 0.06)
	tw.tween_callback(func():
		_spawn_chop_particles(fall_sign)
		_spawn_impact_dust()
		_spawn_logs(fall_sign)
		_play_sound(SFX_IMPACT, -1.5)
	)
	tw.tween_property(canopy, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		canopy.queue_free()
		is_falling = false
	)

func _spawn_impact_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.emitting = false
	dust.explosiveness = 1.0
	dust.amount = 12
	dust.lifetime = 0.5
	dust.direction = Vector2.UP
	dust.spread = 75.0
	dust.initial_velocity_min = 14.0
	dust.initial_velocity_max = 40.0
	dust.gravity = Vector2(0, 100)
	dust.color = Color(0.5, 0.34, 0.2, 0.7)
	dust.position = Vector2(0, 2)
	add_child(dust)
	dust.emitting = true
	get_tree().create_timer(0.7).timeout.connect(dust.queue_free)

func _spawn_logs(fall_sign: float) -> void:
	for i in range(3):
		var log := Sprite2D.new()
		log.texture = LOG_TEX
		log.scale = Vector2(0.1, 0.1)
		log.position = Vector2(0, -8)
		add_child(log)
		var delay := i * 0.1
		var end_x := fall_sign * randf_range(24.0, 48.0)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(log, "position", Vector2(end_x * 0.5, -24.0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(log, "position", Vector2(end_x, randf_range(9.0, 16.0)), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(log, "rotation", deg_to_rad(85.0 * fall_sign), 0.44)
		tw.tween_property(log, "modulate:a", 0.0, 0.25)
		tw.tween_callback(log.queue_free)

func _play_sound(stream: AudioStream, volume: float) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _on_behind_tree_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_node = body

func _on_behind_tree_area_2d_body_exited(body: Node2D) -> void:
	if body == player_node:
		player_node = null
		if color_tween and color_tween.is_valid():
			color_tween.kill()
		color_tween = create_tween()
		color_tween.tween_property(tree_sprite, "modulate:a", 1.0, 0.14)
