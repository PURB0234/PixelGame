extends StaticBody2D

const STAGES = {
		0: preload("res://graphics/plants/oak_tree/stage_1_seed.png"),
		1: preload("res://graphics/plants/oak_tree/stage_2_sprout.png"),
		2: preload("res://graphics/plants/oak_tree/stage_3_sapling.png"),
		3: preload("res://graphics/plants/oak_tree/stage_4_young.png"),
		4: preload("res://graphics/plants/oak_tree/stage_5_mature.png"),
		5: preload("res://graphics/plants/oak_tree/stump_mature_exact.png"),
		6: preload("res://graphics/plants/oak_tree/stump_young_exact.png"),
		7: preload("res://graphics/plants/oak_tree/stump_sapling_exact.png"),
}

const CANOPY_MATURE = preload("res://graphics/plants/oak_tree/canopy_mature.png")
const CANOPY_YOUNG  = preload("res://graphics/plants/oak_tree/canopy_young.png")
const LEAF_TEX      = preload("res://graphics/plants/oak_tree/leaf_particle_1.png")
const LEAF_TEX2     = preload("res://graphics/plants/oak_tree/leaf_particle_2.png")
const WOOD_CHIP_TEX = preload("res://graphics/plants/oak_tree/wood_chip_particle.png")
const LOG_TEX       = preload("res://graphics/plants/oak_tree/wood_log_full.png")
const SFX_FALL = preload("res://audio/falling-tree.wav")
const SFX_IMPACT    = preload("res://audio/tree_impact.wav")
const SFX_CHOP = preload("res://audio/chopping-tree.wav")

# Shadow footprint per growth stage [half-width, half-height] in pixels.
const SHADOW_SIZES = {
		0: Vector2(3.0, 1.5),
		1: Vector2(5.0, 2.5),
		2: Vector2(8.0, 3.0),
		3: Vector2(12.0, 4.5),
		4: Vector2(18.0, 6.0),
		5: Vector2(14.0, 5.0),
		6: Vector2(10.0, 3.8),
		7: Vector2(7.0, 2.8),
}

@export_range(0, 7, 1) var current_stage: int = 4:
		set(value):
				current_stage = clampi(value, 0, 7)
				_update_stage_visual()

@export var random_stage: bool = false

var tree_health: int = 3
var color_tween: Tween
var shake_tween: Tween
var is_falling: bool = false
var player_node: Node2D = null

func _ready() -> void:
		add_to_group("Objects")
		if random_stage:
				current_stage = [2, 3, 4].pick_random()
		_update_stage_visual()

func _process(_delta: float) -> void:
		if player_node and current_stage in [3, 4] and not is_falling:
				var is_strictly_behind: bool = (player_node.global_position.y < global_position.y - 8.0) and (abs(player_node.global_position.x - global_position.x) < 20.0)
				var target_alpha: float = 0.55 if is_strictly_behind else 1.0
				if abs($Sprite2D.modulate.a - target_alpha) > 0.05:
						if color_tween and color_tween.is_valid():
								color_tween.kill()
						color_tween = create_tween()
						color_tween.tween_property($Sprite2D, "modulate:a", target_alpha, 0.15)
		elif $Sprite2D.modulate.a < 0.95 and not is_falling:
				$Sprite2D.modulate.a = 1.0

func _update_stage_visual() -> void:
		if not is_inside_tree() or not has_node("Sprite2D"):
				return
		var tex: Texture2D = STAGES[current_stage]
		$Sprite2D.texture = tex
		$Sprite2D.scale = Vector2(0.1, 0.1)
		$Sprite2D.offset = Vector2(0, -tex.get_height() / 2.0)

		if has_node("Shadow"):
				var sz: Vector2 = SHADOW_SIZES.get(current_stage, Vector2(14.0, 5.5))
				$Shadow.radius_x = sz.x
				$Shadow.radius_y = sz.y
				$Shadow.visible = true
				$Shadow.queue_redraw()

		if current_stage in [4, 5]:
				add_to_group("Axe_able")
				if current_stage == 4:
						add_to_group("Tree")
						tree_health = 3
				else:
						remove_from_group("Tree")
						tree_health = 2
				$CollisionShape2D.disabled = false
				$CollisionShape2D.position = Vector2(0, -4)
				$CollisionShape2D.scale = Vector2(1.2, 1.0)
		elif current_stage in [3, 6]:
				add_to_group("Axe_able")
				if current_stage == 3:
						add_to_group("Tree")
						tree_health = 2
				else:
						remove_from_group("Tree")
						tree_health = 2
				$CollisionShape2D.disabled = false
				$CollisionShape2D.position = Vector2(0, -4)
				$CollisionShape2D.scale = Vector2(0.85, 0.9)
		elif current_stage in [2, 7]:
				add_to_group("Axe_able")
				if current_stage == 2:
						add_to_group("Tree")
						tree_health = 1
				else:
						remove_from_group("Tree")
						tree_health = 1
				$CollisionShape2D.disabled = false
				$CollisionShape2D.position = Vector2(0, -3)
				$CollisionShape2D.scale = Vector2(0.72, 0.8)
		else:
				remove_from_group("Axe_able")
				remove_from_group("Tree")
				$CollisionShape2D.disabled = true

func hit(tool: Enum.Tool, dir: Vector2) -> void:
		if tool != Enum.Tool.AXE or is_falling:
				return
		if current_stage not in [2, 3, 4, 5, 6, 7]:
				return
		_play_sound(SFX_CHOP, 0.0)
		tree_health -= 1
				
		var fall_sign: float = 1.0 if dir.x >= 0 else -1.0

		if color_tween and color_tween.is_valid():
				color_tween.kill()
		color_tween = create_tween()
		$Sprite2D.modulate = Color(2, 2, 2, 1)
		color_tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1, 1), 0.15)

		if shake_tween and shake_tween.is_valid():
				shake_tween.kill()
		shake_tween = create_tween()
		shake_tween.tween_property($Sprite2D, "position:x", 2.5 * fall_sign, 0.045)
		shake_tween.tween_property($Sprite2D, "position:x", -2.0 * fall_sign, 0.045)
		shake_tween.tween_property($Sprite2D, "position:x", 0.0, 0.055)

		_spawn_hit_particles(fall_sign)

		if tree_health <= 0:
				if current_stage == 4:
						Data.ITEMS_AMOUNT[Enum.Item.WOOD] += randi_range(3, 5)
						Data.ITEMS_AMOUNT[Enum.Item.ACORN] += randi_range(1, 2)
						current_stage = 5
						_play_falling_animation(fall_sign, CANOPY_MATURE, -14.5, 3)
				elif current_stage == 3:
						Data.ITEMS_AMOUNT[Enum.Item.WOOD] += 2
						Data.ITEMS_AMOUNT[Enum.Item.ACORN] += 1
						current_stage = 6
						_play_falling_animation(fall_sign, CANOPY_YOUNG, -12.0, 2)
				elif current_stage == 2:
						Data.ITEMS_AMOUNT[Enum.Item.WOOD] += 1
						current_stage = 7
				elif current_stage in [5, 6, 7]:
						Data.ITEMS_AMOUNT[Enum.Item.WOOD] += 1
						_spawn_hit_particles(fall_sign, 10)
						queue_free()

func _spawn_hit_particles(fall_sign: float, amount: int = 6) -> void:
#Daun
		var p_leaf = CPUParticles2D.new()
		p_leaf.texture = LEAF_TEX if randf() > 0.4 else LEAF_TEX2
		p_leaf.emitting = false
		p_leaf.one_shot = true
		p_leaf.explosiveness = 0.85
		p_leaf.amount = amount
		p_leaf.lifetime = 0.9
		p_leaf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p_leaf.emission_rect_extents = Vector2(7.0, 3.0)
		p_leaf.scale_amount_min = 0.9
		p_leaf.scale_amount_max = 1.4
		p_leaf.direction = Vector2(fall_sign, -1.0)
		p_leaf.spread = 55.0
		p_leaf.initial_velocity_min = 35.0
		p_leaf.initial_velocity_max = 75.0
		p_leaf.gravity = Vector2(0, 130)
		p_leaf.position = Vector2(fall_sign * 4.0, -18)
		add_child(p_leaf)
		p_leaf.emitting = true
		get_tree().create_timer(1.1).timeout.connect(p_leaf.queue_free)

#Serpihan kayu — lebih sedikit, arah lebih rendah
		var p_chip = CPUParticles2D.new()
		p_chip.texture = WOOD_CHIP_TEX
		p_chip.emitting = false
		p_chip.one_shot = true
		p_chip.explosiveness = 0.95
		p_chip.amount = ceili(amount * 0.5)
		p_chip.lifetime = 0.5
		p_chip.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p_chip.emission_rect_extents = Vector2(3.0, 2.0)
		p_chip.scale_amount_min = 0.8
		p_chip.scale_amount_max = 1.2
		p_chip.direction = Vector2(fall_sign, -0.3)
		p_chip.spread = 35.0
		p_chip.initial_velocity_min = 50.0
		p_chip.initial_velocity_max = 100.0
		p_chip.gravity = Vector2(0, 200)
		p_chip.position = Vector2(0, -8)
		add_child(p_chip)
		p_chip.emitting = true
		get_tree().create_timer(0.6).timeout.connect(p_chip.queue_free)

func _spawn_logs(fall_sign: float, count: int) -> void:
		for i in range(count):
				var log_sprite = Sprite2D.new()
				log_sprite.texture = LOG_TEX
				log_sprite.scale = Vector2(0.1, 0.1)
				log_sprite.position = Vector2(0, -10)
				add_child(log_sprite)

				var delay = i * 0.12
				var throw_x = fall_sign * randf_range(28.0, 55.0)
				var throw_y = randf_range(-30.0, -15.0)
				var land_y = randf_range(10.0, 22.0)
				var dur = randf_range(0.45, 0.65)

				var tw = create_tween()
				tw.tween_interval(delay)
#Fase 1: lempar ke udara (parabola atas)
				tw.tween_property(log_sprite, "position", Vector2(throw_x * 0.5, throw_y), dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#Fase 2: jatuh ke tanah
				tw.tween_property(log_sprite, "position", Vector2(throw_x, land_y), dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
#Rotasi
				tw.parallel().tween_property(log_sprite, "rotation", deg_to_rad(randf_range(60.0, 120.0) * fall_sign), dur)
#Fade out setelah mendarat
				tw.tween_property(log_sprite, "modulate:a", 0.0, 0.3)
				tw.tween_callback(log_sprite.queue_free)

func _play_falling_animation(fall_sign: float, canopy_tex: Texture2D, pivot_y: float, log_count: int) -> void:
		is_falling = true
		_play_sound(SFX_FALL, -2.0)
		var canopy = Sprite2D.new()
		canopy.texture = canopy_tex
		canopy.scale = Vector2(0.1, 0.1)
		canopy.position = Vector2(0, pivot_y)
		canopy.offset = Vector2(0, -canopy_tex.get_height() / 2.0)
		add_child(canopy)
		var target_rot = deg_to_rad(90.0 * fall_sign)
		var tween = create_tween()
		tween.tween_property(canopy, "rotation", deg_to_rad(-4.0 * fall_sign), 0.12).set_trans(Tween.TRANS_SINE)
		tween.tween_property(canopy, "rotation", target_rot, 0.75).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_property(canopy, "rotation", target_rot - deg_to_rad(8.0 * fall_sign), 0.09)
		tween.tween_property(canopy, "rotation", target_rot + deg_to_rad(3.0 * fall_sign), 0.07)
		tween.tween_property(canopy, "rotation", target_rot, 0.06)
		tween.tween_callback(func():
				_spawn_hit_particles(fall_sign, 22)
				_spawn_logs(fall_sign, log_count)
				_spawn_impact_dust(fall_sign)
				_play_sound(SFX_IMPACT, -1.5)
		)
		tween.tween_property(canopy, "modulate:a", 0.0, 0.35)
		tween.tween_callback(func():
				canopy.queue_free()
				is_falling = false
		)

func _spawn_impact_dust(fall_sign: float) -> void:
		var dust = CPUParticles2D.new()
		dust.emitting = false
		dust.one_shot = true
		dust.explosiveness = 1.0
		dust.amount = 10
		dust.lifetime = 0.45
		dust.direction = Vector2(fall_sign, -0.15)
		dust.spread = 75.0
		dust.initial_velocity_min = 12.0
		dust.initial_velocity_max = 38.0
		dust.gravity = Vector2(0, 90)
		dust.color = Color(0.48, 0.34, 0.22, 0.7)
		dust.position = Vector2(0, 1)
		add_child(dust)
		dust.emitting = true
		get_tree().create_timer(0.6).timeout.connect(dust.queue_free)

func _play_sound(stream: AudioStream, vol_db: float) -> void:
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = stream
		audio_player.volume_db = vol_db
		add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

func grow_day() -> void:
		if current_stage < 4:
				current_stage += 1

func create_apple() -> void:
		pass

func _on_behind_tree_area_2d_body_entered(body: Node2D) -> void:
		if body.is_in_group("Player"):
				player_node = body

func _on_behind_tree_area_2d_body_exited(body: Node2D) -> void:
		if body == player_node:
				player_node = null
				if color_tween and color_tween.is_valid():
						color_tween.kill()
				color_tween = create_tween()
				color_tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.15)
