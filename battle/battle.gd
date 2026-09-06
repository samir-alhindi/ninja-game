class_name Battle extends Node2D

@export var distance_between_enemies := 40

@onready var battlers: Node2D = %Battlers
@onready var text_box: TextureRect = %TextBox
@onready var battle_text: RichTextLabel = %BattleText
@onready var battle_camera: Camera2D = %BattleCamera
@onready var music: AudioStreamPlayer = %Music
@onready var ally_spawn_circle: Marker2D = %AllySpawnCircle
@onready var ally_spawn_point: Marker2D = %AllySpawnPoint
@onready var enemy_spawn_origin_point: Marker2D = %EnemySpawnOriginPoint
@onready var rotation_count_label: RichTextLabel = %RotationCountLabel
@onready var error_sound: AudioStreamPlayer = %ErrorSound
@onready var rotation_timer: Timer = %RotationTimer
@onready var battler_health_label: Label = %BattlerHealthLabel
@onready var battler_magic_label: RichTextLabel = %BattlerMagicLabel
@onready var battler_data_ui: VBoxContainer = %BattlerDataUI
@onready var health_receptacle: Receptacle = %HealthReceptacle
@onready var magic_receptacle: Receptacle = %MagicReceptacle
@onready var text_timer: Timer = %TextTimer
@onready var text_sound: AudioStreamPlayer = %TextSound
@onready var move_sound: AudioStreamPlayer = %MoveSound
@onready var button_prompt_confirm: Node2D = %ButtonPrompt
@onready var selection_cursor: SelectionCursor = %SelectionCursor
@onready var instructions_container: HBoxContainer = %InstructionsContainer
@onready var start_rotate_label: RichTextLabel = %StartRotateLabel
@onready var cancel_label: RichTextLabel = %CancelLabel
@onready var do_rotate_label: RichTextLabel = %DoRotateLabel
@onready var rotation_receptacle: Receptacle = %RotationReceptacle
@onready var rotation_data_ui: VBoxContainer = %RotationDataUI
@onready var end_turn_label: RichTextLabel = %EndTurnLabel

var battle_data: BattleData
var allies_data: Array[AllyBattlerData]

var allies: Array[AllyBattler] = []
var enemies_grid: Array[EnemyBattlerRow] = []
var has_not_played_turn: Array[AllyBattler] = []

var num_of_living_allies := 0
var num_of_living_enemies := 0
var exp_gained: int
var ally_selection_index := 0
var number_of_rotations_left := 0
var num_of_allies_who_finished_increasing_xp := 0

const INTRO_ANIM_WALK_DISTANCE := 60

enum States {
	BATTLER_PLAYING_TURNS,
	SELECTING_ALLY,
	ROTATING,
	CHOOSING_ROTATION,
}
var state := States.BATTLER_PLAYING_TURNS

static var is_debuging := false

static func create(allies_data: Array[AllyBattlerData], battle_data: BattleData) -> Battle:
	const BATTLE = preload("uid://cb3474ae6wcck")
	var battle: Battle = BATTLE.instantiate()
	battle.allies_data = allies_data
	battle.battle_data = battle_data
	return battle

func _ready() -> void:
	EventBus.display_text.connect(display_text)
	EventBus.give_extra_turn.connect(give_extra_turn)
	MyInput.input_mode_changed.connect(_on_input_mode_changed)
	# Spawn background:
	var background_scene := BattleData.BACKGROUNDS[battle_data.background_type]
	var background: Node2D = background_scene.instantiate()
	add_child(background)
	
	enemies_grid = []
	for i in range(battle_data.grid_size):
		var row := EnemyBattlerRow.new()
		enemies_grid.append(row)
		row.elements.resize(battle_data.grid_size)
	
	allies = []
	# Spawn allies:
	for data in allies_data:
		var ally := Battler.create(data) as AllyBattler
		ally._enemies_grid = enemies_grid
		ally._allies = allies
		battlers.add_child(ally)
		num_of_living_allies += 1
		ally.died.connect(func(): num_of_living_allies -= 1)
		ally.started_turn.connect(_on_ally_started_turn)
		ally.finished_turn.connect(_on_ally_finished_turn.bind(ally))
		ally.update_battler_ui.connect(update_battler_data_ui)
		ally.skill_button_focused.connect(_on_skill_button_focused)
		ally.cancel_my_turn.connect(cancel_ally_turn)
		allies.append(ally)
		var step := 360.0 / 4
		ally_spawn_circle.rotation_degrees += step
		ally.global_position = ally_spawn_point.global_position
		ally.global_position.x -= INTRO_ANIM_WALK_DISTANCE
	
	# Spawn enemies:
	for i in range(battle_data.enemies_data_grid.size()):
		var row := battle_data.enemies_data_grid[i].elements
		for j in range(row.size()):
			if row[j] == null:
				continue
			exp_gained += row[j].exp_worth
			var enemy := Battler.create(row[j]) as EnemyBattler
			enemy._enemies_grid = enemies_grid
			enemy._allies = allies
			battlers.add_child(enemy)
			num_of_living_enemies += 1
			enemy.died.connect(func(): num_of_living_enemies -= 1)
			enemies_grid[i].elements[j] = enemy
			enemy.global_position = (
				enemy_spawn_origin_point.global_position + Vector2(
				distance_between_enemies * j + INTRO_ANIM_WALK_DISTANCE,
				distance_between_enemies * i
			))
	battle_camera.make_current()
	text_box.hide()
	button_prompt_confirm.hide()
	battler_data_ui.hide()
	
	for node in instructions_container.get_children():
		if node is RichTextLabel:
			Util.format_button_icons_to_rich_text_label(node)

func start() -> void:
	for ally in allies:
		ally.move_to(Vector2(ally.global_position.x + INTRO_ANIM_WALK_DISTANCE, ally.global_position.y))
		await get_tree().create_timer(0.1).timeout
	for row in enemies_grid:
		for enemy in row.elements:
			if enemy and enemy.is_alive:
				enemy.move_to(Vector2(
					enemy.global_position.x - INTRO_ANIM_WALK_DISTANCE, enemy.global_position.y
				))
				await get_tree().create_timer(0.1).timeout
	instructions_container.show()
	start_ally_turn()

func start_ally_turn() -> void:
	start_rotate_label.show()
	end_turn_label.show()
	selection_cursor.show_button_prompt()
	for ally in allies:
		ally.stop_guarding()
	has_not_played_turn = allies.filter(func(ally: AllyBattler): return ally.is_alive)
	number_of_rotations_left = 6
	rotation_receptacle.update(1.0)
	state = States.SELECTING_ALLY
	ally_selection_index = next_ally_index()
	update_battler_data_ui(allies[ally_selection_index])
	EventBus.move_cursor_to.emit(allies[ally_selection_index].global_position)
	EventBus.set_cursor_visible.emit(true)

func enemy_turn() -> void:
	start_rotate_label.hide()
	end_turn_label.hide()
	selection_cursor.hide_button_prompt()
	for row in enemies_grid:
		for enemy in row.elements:
			if not enemy or not enemy.is_alive:
				continue
			enemy.play_turn()
			await enemy.finished_turn
			if is_battle_finished():
				finish_battle()
				return
	start_ally_turn()

func _on_ally_finished_turn(ally: AllyBattler) -> void:
	await get_tree().create_timer(0.1).timeout
	cancel_label.hide()
	start_rotate_label.show()
	end_turn_label.show()
	if is_battle_finished():
		finish_battle()
		return
	has_not_played_turn.erase(ally)
	state = States.SELECTING_ALLY
	ally_selection_index = next_ally_index()
	EventBus.set_cursor_visible.emit(true)
	update_battler_data_ui(allies[ally_selection_index])
	EventBus.move_cursor_to.emit(allies[ally_selection_index].global_position)

func _input(event: InputEvent) -> void:
	
	if event.is_action("god_mode") and OS.is_debug_build():
		is_debuging = true
		for ally in allies:
			ally._strength = 99999
	
	if event.is_action("enemies_god_mod") and OS.is_debug_build():
		is_debuging = true
		for row in enemies_grid:
			for enemy in row.elements:
				if enemy and enemy.is_alive:
					enemy._strength = 9999
	
	if state == States.ROTATING:
		return
	
	if text_box.visible and event.is_action_pressed("primary action"):
		text_timer.stop()
		if battle_text.visible_ratio == 1.0:
			text_box.hide()
			button_prompt_confirm.hide()
			EventBus.textbox_closed.emit()
		else:
			button_prompt_confirm.show()
			battle_text.visible_ratio = 1.0
	
	elif state == States.SELECTING_ALLY:
		if EventBus.is_cursor_moving:
			return
		var moved := true
		if event.is_action_pressed("move right"):
			ally_selection_index = 0
		elif event.is_action_pressed("move down"):
			ally_selection_index = 1
		elif event.is_action_pressed("move left"):
			ally_selection_index = 2
		elif event.is_action_pressed("move up"):
			ally_selection_index = 3
		else:
			moved = false
		if moved:
			EventBus.move_cursor_to.emit(allies[ally_selection_index].global_position)
			update_battler_data_ui(allies[ally_selection_index])
		
		if event.is_action_pressed("primary action"):
			var ally := allies[ally_selection_index]
			if ally.played_turn or not ally.is_alive:
				ally.error_sound.play()
				return
			state = States.BATTLER_PLAYING_TURNS
			start_rotate_label.hide()
			end_turn_label.hide()
			
			cancel_label.show()
			await get_tree().create_timer(0.1).timeout
			ally.play_turn()
		
		elif event.is_action_pressed("tertiary action"):
			battler_data_ui.hide()
			start_rotate_label.hide()
			end_turn_label.hide()
			do_rotate_label.show()
			cancel_label.show()
			rotation_data_ui.show()
			rotation_count_label.text = "RP %d/6" % number_of_rotations_left
			state = States.CHOOSING_ROTATION
			EventBus.set_cursor_visible.emit(false)
		
		elif event.is_action_pressed("quaternary action"):
			for a in allies:
				a.played_turn = false
				if a.is_alive:
					a.animated_sprite_2d.modulate.a = 1.0
			await get_tree().create_timer(0.1).timeout
			state = States.BATTLER_PLAYING_TURNS
			enemy_turn()
	
	elif state == States.CHOOSING_ROTATION:
		var dir: int
		if event.is_action_pressed("move left"):
			dir = -1
		if event.is_action_pressed("move right"):
			dir = 1
		if dir != 0:
			if number_of_rotations_left <= 0:
				error_sound.play()
				return
			state = States.ROTATING
			number_of_rotations_left -= 1
			rotation_count_label.text = "RP %d/6" % number_of_rotations_left
			rotation_receptacle.update(float(number_of_rotations_left) / 6)
			rotation_timer.start(allies[0].movement_speed)
			for i in range(allies.size()):
				allies[i].move_to(allies[(i+dir) % allies.size()].global_position, false)
			if dir == 1:
				var last: AllyBattler = allies.pop_back()
				allies.push_front(last)
			else:
				var first: AllyBattler = allies.pop_front()
				allies.append(first)
		elif event.is_action_pressed("secondary action"):
			rotation_timer.stop()
			do_rotate_label.hide()
			cancel_label.hide()
			start_rotate_label.show()
			end_turn_label.show()
			rotation_data_ui.hide()
			state = States.SELECTING_ALLY
			EventBus.set_cursor_visible.emit(true)
			EventBus.move_cursor_to.emit(allies[0].global_position)
			update_battler_data_ui(allies[0])

func update_battler_data_ui(battler: Battler) -> void:
	if battler is AllyBattler:
		battler_data_ui.show()
		battler_health_label.text = "HP %d/%d" % [battler._health, battler._max_health]
		health_receptacle.show()
		health_receptacle.update(float(battler._health) / battler._max_health)
		magic_receptacle.show()
		magic_receptacle.update(float(battler._magic_points) / battler._max_magic_points)
		battler_magic_label.show()
		battler_magic_label.text = "MP %d/%d" % [battler._magic_points, battler._max_magic_points]
	else:
		battler_data_ui.hide()

func display_text(text: String) -> void:
	$DisplayTextSound.play()
	battler_data_ui.hide()
	text_box.show()
	battle_text.text = text
	battle_text.visible_characters = 0
	text_timer.start()

func allies_won() -> bool:
	return num_of_living_enemies == 0

func enemies_won() -> bool:
	return num_of_living_allies == 0 

func is_battle_finished() -> bool:
	return allies_won() or enemies_won()

func finish_battle() -> void:
	instructions_container.hide()
	music.stop()
	if allies_won():
		display_text("You Won !")
		await EventBus.textbox_closed
		text_box.hide()
		for ally in allies:
			ally.increase_exp(exp_gained)
			ally.finished_increasing_xp.connect(
				func():
					num_of_allies_who_finished_increasing_xp += 1
					if num_of_allies_who_finished_increasing_xp == 4:
						for a in allies:
							await a.level_up()
						EventBus.battle_finished.emit()
			)
	else:
		display_text("Game Over...")
		await EventBus.textbox_closed
		get_tree().change_scene_to_file("res://game/game.tscn")

func _on_skill_button_focused(skill_cost: int, current_magic: int, max_magic: int) -> void:
	var magic_after_using_skill := float(current_magic - skill_cost)
	battler_magic_label.text = "MP %d/%d" % [magic_after_using_skill, max_magic]
	magic_receptacle.update(magic_after_using_skill / max_magic)

func _on_rotation_timer_timeout() -> void:
	state = States.CHOOSING_ROTATION

func cancel_ally_turn() -> void:
	state = States.SELECTING_ALLY
	start_rotate_label.show()
	end_turn_label.show()
	cancel_label.hide()

func give_extra_turn(ally: AllyBattler) -> void:
	ally.played_turn = false
	if ally.is_alive:
		ally.animated_sprite_2d.modulate.a = 1.0
	has_not_played_turn.append(ally)

func _on_text_timer_timeout() -> void:
	battle_text.visible_characters += 1
	if battle_text.visible_ratio != 1.0:
		text_timer.start()
	else:
		button_prompt_confirm.show()
	if battle_text.visible_characters % 2 == 0:
		text_sound.play()

func _on_input_mode_changed() -> void:
	for node in instructions_container.get_children():
		if node is RichTextLabel:
			var tags: Array = node.get_meta("tags")
			for tag: String in tags:
				node.update_image(
					tag,
					RichTextLabel.UPDATE_TEXTURE,
					MyInput.get_icon(tag)
				)

func _on_ally_started_turn() -> void:
	cancel_label.hide()

func next_ally_index() -> int:
	if len(has_not_played_turn) > 0:
		return allies.find(has_not_played_turn[0])
	return 0
