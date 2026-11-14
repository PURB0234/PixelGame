# TODO: Move while using tools 
extends CharacterBody2D

var debug: bool = true

# Player health
signal health_changed(current_health: int, max_health: int)
signal player_died
var max_health: int = Data.PLAYER_MAX_HEALTH
var health: int = Data.PLAYER_MAX_HEALTH
var is_dead: bool = false
var invulnerability_time: float = 0.0
const INVULNERABILITY_DURATION: float = 0.8
var health_ui: CanvasLayer

const SPEED: float = Data.PLAYER_SPEED
var direction: Vector2
var can_move: bool = true
var target_position: Vector2 = Vector2.ZERO
var is_moving_to_target: bool = false
@onready var move_state_machine = $Animation/AnimationTree.get("parameters/StateMachine/playback")

@onready var tool_state_machine = $Animation/AnimationTree.get("parameters/ToolStateMachine/playback")
var current_tool: Enum.Tool = Enum.Tool.AXE
var tools_count: int = Enum.Tool.size()

var current_seed: Enum.Seed = Enum.Seed.TOMATO
var seeds_count: int = Enum.Seed.size()

var current_state: Enum.State = Enum.State.DEFAULT

var current_style: Enum.Style = Enum.Style.STRAW
var style_count: int = Data.unlocked_styles.size()
var style_index: int = 0

var current_machine: Enum.Machine = Enum.Machine.DELETE
var machine_count = Data.unlocked_machines.size()
var machine_index: int = 0
signal build(machine: Enum.Machine)
signal change_machine(machine: Enum.Machine)

var animation_direction: Vector2 = Vector2(0, 1)

# One-click tree chopping: keep the selected tree until it becomes a stump.
var auto_chop_target: Node2D = null
var auto_chop_active: bool = false
var auto_chop_swing_pending: bool = false
var auto_chop_swing_cooldown: float = 0.0
var auto_chop_stuck_time: float = 0.0
var auto_chop_last_pos: Vector2 = Vector2.ZERO
const AUTO_CHOP_SWING_INTERVAL: float = 0.72
# Stand distance must stay well below the axe hit range in level.gd (< 22) and
# below AUTO_CHOP_RANGE minus the arrival tolerance used by move() (4.0).
const AUTO_CHOP_RANGE: float = 20.0
const AUTO_CHOP_STAND_DISTANCE: float = 14.0
const AUTO_CHOP_STUCK_TIMEOUT: float = 1.0

signal tool_use(tool: Enum.Tool, pos: Vector2, dir: Vector2)
signal do_action(anim_tree: AnimationTree, property: StringName, tool: Enum.Tool, pos: Vector2, dir: Vector2)

signal diagnose
signal day_change

var can_interact: bool = false
var last_interactable

signal update_control_ui(key_enum: Enum.KEYBOARD, currentItem: Enum)

signal close_shop 

var update_state: Enum.State = Enum.State.HOUSE;


func _ready():
	var health_ui_scene = preload("res://scenes/ui/health_bar.tscn")
	health_ui = health_ui_scene.instantiate()
	add_child(health_ui)
	health_ui.update_health(health, max_health)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # No sliding/pushing
	var player_light: PointLight2D = PointLight2D.new()
	$".".add_child(player_light)
	
	# Create smooth faded circle texture
	var size = 256
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Fill with transparent
	
	var center = size / 2.0
	var max_radius = size / 2.0
	
	for x in size:
		for y in size:
			var dx = x - center
			var dy = y - center
			var distance = sqrt(dx * dx + dy * dy)
			
			if distance <= max_radius:
				# Calculate alpha: 1.0 at center, 0.0 at edge
				var alpha = 1.0 - (distance / max_radius)
				# Square it for smoother fade
				alpha = alpha * alpha
				
				# Set pixel color with alpha
				var color = Color(1.0, 1.0, 0.9, alpha)
				image.set_pixel(x, y, color)
	
	# Create texture and apply
	var texture = ImageTexture.create_from_image(image)
	player_light.texture = texture
	player_light.energy = 0.25
	player_light.texture_scale = 0.5


func _physics_process(delta: float) -> void:
	if invulnerability_time > 0.0:
		invulnerability_time = maxf(invulnerability_time - delta, 0.0)
		$Sprite2D.visible = int(invulnerability_time * 12.0) % 2 == 0
	elif not is_dead:
		$Sprite2D.visible = true

	if is_dead:
		velocity = Vector2.ZERO
		return

	if update_state != current_state:
		if current_state == Enum.State.BUILDING:
			update_control_ui.emit(Enum.KEYBOARD.CHANGE_MODE, current_state, Enum.State.BUILDING)		
		else:
			update_control_ui.emit(Enum.KEYBOARD.CHANGE_MODE, current_state)		
			
		update_state = current_state
		
	match current_state:
		Enum.State.DEFAULT:
			if can_move:
				get_basic_input()
				move()
				animate()
			_process_auto_chop(delta)
		
		Enum.State.FISHING:
			get_fishing_input()
		
		Enum.State.BUILDING:
			get_fishing_input()
			get_building_input()
			move()
			animate()
			
		Enum.State.HOUSE:
			get_house_input()
			move()
			animate()
			
		Enum.State.SHOP:
			get_shop_input()
				
	
func move():
		var keyboard_dir: Vector2 = Input.get_vector("left", "right", "up", "down")
		if keyboard_dir != Vector2.ZERO:
				_cancel_auto_chop()
				is_moving_to_target = false
				direction = keyboard_dir
		elif is_moving_to_target:
				var diff: Vector2 = target_position - global_position
				if diff.length() > 4.0:
						direction = diff.normalized()
				else:
						is_moving_to_target = false
						direction = Vector2.ZERO
		else:
				direction = Vector2.ZERO

		velocity = direction * SPEED

		if direction:
				if not $Sounds/StepTimer.time_left:
						$Sounds/StepTimer.start()
		else:
				$Sounds/Step.stop()

		move_and_slide()
	
	
func get_basic_input():
	# Switch seeds
	if Input.is_action_just_pressed("seed_forward"):
		current_seed = posmod((current_seed + 1), seeds_count) as Enum.Seed
		if debug:
			print("Current Seed:" + Enum.Seed.keys()[current_seed])
		$ToolUI.reveal(null, current_seed)
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_SEED, current_seed)
		
	# Switch tools
	var dir := 0
	if Input.is_action_just_pressed("tool_forward"):
		dir = 1
	elif Input.is_action_just_pressed("tool_backward"):
		dir = -1

	if dir != 0:
		current_tool = posmod((current_tool + dir), tools_count) as Enum.Tool
		if current_tool != Enum.Tool.AXE:
			_cancel_auto_chop()
		$ToolUI.reveal(current_tool, null)
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_TOOL, current_tool)

	if Input.is_action_just_pressed("action"):
		var mouse_pos: Vector2 = get_global_mouse_position()
		var mouse_offset: Vector2 = mouse_pos - global_position
		var clicked_tree: Node2D = _get_clicked_tree(mouse_pos) if current_tool == Enum.Tool.AXE else null

		if clicked_tree:
			_begin_auto_chop(clicked_tree)
		else:
			_cancel_auto_chop()
			var click_dir: Vector2 = Vector2.DOWN
			if abs(mouse_offset.x) > abs(mouse_offset.y):
				click_dir = Vector2.RIGHT if mouse_offset.x > 0 else Vector2.LEFT
			else:
				click_dir = Vector2.DOWN if mouse_offset.y > 0 else Vector2.UP
			update_facing_direction(click_dir)

			# Klik jauh tetap memakai sistem auto-walk yang sudah ada.
			if mouse_offset.length() > 28.0:
				target_position = mouse_pos
				is_moving_to_target = true
			else:
				is_moving_to_target = false
				if can_interact and last_interactable:
					last_interactable.interact(self)
				else:
					tool_state_machine.travel(Data.TOOL_STATE_ANIMATIONS[current_tool])
					do_action.emit($Animation/AnimationTree, "parameters/OneShot/request", current_tool, position, animation_direction)
		
	if Input.is_action_just_pressed("highlighter"):
		Data.TARGET_HIGHLIGHTER = not Data.TARGET_HIGHLIGHTER 
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_HIGHLIGHT, 1 if Data.TARGET_HIGHLIGHTER else 0)

	if Input.is_action_just_pressed("day_change"):
		day_change.emit()
		
	if Input.is_action_just_pressed("diagnose"):
		diagnose.emit()
		
	if Input.is_action_just_pressed("style_toggle"):
		style_count = Data.unlocked_styles.size()
		style_index = posmod((style_index + 1), style_count - 1)
		current_style = Data.unlocked_styles[style_index] as Enum.Style
		print(current_style)
		$Sprite2D.texture = Data.PLAYER_SKINS[current_style]
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_STYLE, current_style)
		
	if Input.is_action_just_pressed("build"):
		current_state = Enum.State.BUILDING
		change_machine.emit(current_machine)
		Data.TARGET_HIGHLIGHTER = false
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_HIGHLIGHT, 0)
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_MACHINE, current_machine, Enum.State.BUILDING)
		
		

func get_fishing_input():
	if Input.is_action_just_pressed("action"):
		$FishingGame.apply_bar_boost()


func get_building_input():
	if Input.is_action_just_pressed("build"):
		current_state = Enum.State.DEFAULT
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_TOOL, current_tool)
		
	
	# Switch Machines
	var dir := 0
	if Input.is_action_just_pressed("tool_forward"):
		dir = 1
	elif Input.is_action_just_pressed("tool_backward"):
		dir = -1

	if dir != 0:
		machine_count = Data.unlocked_machines.size()
		machine_index = posmod((machine_index + dir), machine_count) as Enum.Machine
		current_machine = Data.unlocked_machines[machine_index] as Enum.Machine
		change_machine.emit(current_machine)
		if debug:
			print("Machine" + str(current_machine))
			
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_MACHINE, current_machine, Enum.State.BUILDING)
		
			
	if Input.is_action_just_pressed("action"):
		build.emit(current_machine)


func get_house_input():
	if Input.is_action_just_pressed("diagnose"):
		diagnose.emit()
		
	if Input.is_action_just_pressed("style_toggle"):
		current_style = posmod((current_style + 1), style_count - 1) as Enum.Style
		$Sprite2D.texture = Data.PLAYER_SKINS[current_style]
		
	if Input.is_action_just_pressed("action"):
		if can_interact and last_interactable:
			last_interactable.interact(self)
	
	
func get_shop_input():
	if Input.is_action_just_pressed("ui_cancel"):
		close_shop.emit()


func animate():
		if direction:
				move_state_machine.travel("walk")
				var anim_dir: Vector2 = Vector2.DOWN
				if abs(direction.x) > abs(direction.y):
						anim_dir = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
				else:
						anim_dir = Vector2.DOWN if direction.y > 0 else Vector2.UP
				update_facing_direction(anim_dir)
		else:
				move_state_machine.travel("idle")


func update_facing_direction(new_dir: Vector2) -> void:
		animation_direction = new_dir
		$Animation/AnimationTree.set("parameters/StateMachine/idle/blend_position", animation_direction)
		$Animation/AnimationTree.set("parameters/StateMachine/walk/blend_position", animation_direction)
		$Animation/AnimationTree.set("parameters/FishIdleBlendSpace2D/blend_position", animation_direction)
		for tool_animation in Data.TOOL_STATE_ANIMATIONS.values():
				$Animation/AnimationTree.set("parameters/ToolStateMachine/" + tool_animation + "/blend_position", animation_direction)
	
		
func _get_clicked_tree(mouse_pos: Vector2) -> Node2D:
	var selected_tree: Node2D = null
	var nearest_distance: float = INF
	for node in get_tree().get_nodes_in_group("Tree"):
		var candidate := node as Node2D
		if candidate == null or not candidate.is_in_group("Axe_able"):
			continue
		var sprite := candidate.get_node_or_null("Sprite2D") as Sprite2D
		var clicked := false
		if sprite and sprite.texture:
			clicked = sprite.get_rect().has_point(sprite.to_local(mouse_pos))
		else:
			clicked = candidate.global_position.distance_to(mouse_pos) <= 18.0
		if clicked:
			var distance := candidate.global_position.distance_to(mouse_pos)
			if distance < nearest_distance:
				nearest_distance = distance
				selected_tree = candidate
	return selected_tree


# Axe animations are blended per direction; a diagonal blend position plays two
# animations at once and fires tool_use_emit twice (double damage). Snap to 4 directions.
func _to_cardinal(vec: Vector2) -> Vector2:
	if vec == Vector2.ZERO:
		return animation_direction
	if abs(vec.x) > abs(vec.y):
		return Vector2.RIGHT if vec.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if vec.y > 0.0 else Vector2.UP


func _begin_auto_chop(tree: Node2D) -> void:
	auto_chop_target = tree
	auto_chop_active = true
	auto_chop_swing_pending = false
	auto_chop_stuck_time = 0.0
	auto_chop_last_pos = global_position
	is_moving_to_target = false
	_process_auto_chop()


func _cancel_auto_chop() -> void:
	auto_chop_active = false
	auto_chop_swing_pending = false
	auto_chop_swing_cooldown = 0.0
	auto_chop_stuck_time = 0.0
	auto_chop_target = null
	is_moving_to_target = false


func _process_auto_chop(delta: float = 0.0) -> void:
	if not auto_chop_active:
		return
	if current_state != Enum.State.DEFAULT or current_tool != Enum.Tool.AXE or is_dead:
		_cancel_auto_chop()
		return
	if not is_instance_valid(auto_chop_target):
		_cancel_auto_chop()
		return
	if not auto_chop_target.is_in_group("Tree") or not auto_chop_target.is_in_group("Axe_able"):
		# Stop when the tree has fallen; leave its stump untouched.
		_cancel_auto_chop()
		return

	var to_tree: Vector2 = auto_chop_target.global_position - global_position
	if to_tree.length() > AUTO_CHOP_RANGE:
		var approach_direction := to_tree.normalized()
		update_facing_direction(_to_cardinal(approach_direction))
		target_position = auto_chop_target.global_position - approach_direction * AUTO_CHOP_STAND_DISTANCE
		is_moving_to_target = true
		# Give up if the player cannot make progress (blocked path) instead of freezing.
		if delta > 0.0:
			if global_position.distance_to(auto_chop_last_pos) < 0.1:
				auto_chop_stuck_time += delta
				if auto_chop_stuck_time >= AUTO_CHOP_STUCK_TIMEOUT:
					_cancel_auto_chop()
					return
			else:
				auto_chop_stuck_time = 0.0
		auto_chop_last_pos = global_position
		return
	auto_chop_stuck_time = 0.0

	is_moving_to_target = false
	var chop_direction: Vector2 = _to_cardinal(to_tree)
	update_facing_direction(chop_direction)
	if auto_chop_swing_pending:
		auto_chop_swing_cooldown -= delta
		if auto_chop_swing_cooldown > 0.0:
			return
		auto_chop_swing_pending = false
		can_move = true

	auto_chop_swing_pending = true
	auto_chop_swing_cooldown = AUTO_CHOP_SWING_INTERVAL
	tool_state_machine.travel(Data.TOOL_STATE_ANIMATIONS[Enum.Tool.AXE])
	do_action.emit($Animation/AnimationTree, "parameters/OneShot/request", Enum.Tool.AXE, position, animation_direction)


func tool_use_emit():
	tool_use.emit(current_tool, position, animation_direction)
	if current_tool == Enum.Tool.AXE or current_tool == Enum.Tool.SWORD:
		$Sounds/Axe.play()
	elif current_tool == Enum.Tool.FISH:
		$Sounds/Fish.play()
	elif current_tool == Enum.Tool.HOE:
		$Sounds/Hoe.play()	
	elif current_tool == Enum.Tool.WATER:
		$Sounds/Water.play()	


func _on_animation_tree_animation_started(_anim_name: StringName) -> void:
	can_move = false


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	can_move = true
	if auto_chop_active and String(anim_name).begins_with("axe_"):
		auto_chop_swing_pending = false
		auto_chop_swing_cooldown = 0.0
		call_deferred("_process_auto_chop", 0.0)


# Fishing Part
func start_fishing():
	$FishingGame.reveal()
	$Animation/AnimationTree.set("parameters/FishBlend/blend_amount", 1)
	current_state = Enum.State.FISHING


func _on_fishing_game_fish_game_finish(is_success: bool) -> void:
	if is_success:
		Data.ITEMS_AMOUNT[Enum.Item.FISH] += 1
	$Animation/AnimationTree.set("parameters/FishBlend/blend_amount", 0)
	current_state = Enum.State.DEFAULT



# Interact: this method only work if there is only 1 interactable in area 2D
func _on_interact_range_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("interact"):
		body.can_interact = true
		can_interact = true
		last_interactable = body



func _on_interact_range_area_2d_body_exited(body: Node2D) -> void:
	can_interact = false
	last_interactable = null
	if body.has_method("interact"):
		body.can_interact = false

	
	


func _on_step_timer_timeout() -> void:
	$Sounds/Step.play()


# Called by enemies and hazards when the player is hit.
func take_damage(amount: int = 1) -> void:
	if is_dead or invulnerability_time > 0.0 or amount <= 0:
		return

	health = maxi(health - amount, 0)
	invulnerability_time = INVULNERABILITY_DURATION
	health_changed.emit(health, max_health)
	if health_ui:
		health_ui.update_health(health, max_health)
	if health <= 0:
		is_dead = true
		velocity = Vector2.ZERO
		$Sprite2D.visible = true
		player_died.emit()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	if health_ui:
		health_ui.update_health(health, max_health)


func restore_health() -> void:
	is_dead = false
	health = max_health
	health_changed.emit(health, max_health)
	invulnerability_time = 0.0
	$Sprite2D.visible = true
	if health_ui:
		health_ui.update_health(health, max_health)
