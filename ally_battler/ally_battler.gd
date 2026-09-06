class_name AllyBattler extends Battler

signal skill_button_focused(skill_cost: int, current_magic: int, max_magic: int)
signal cancel_my_turn
signal finished_increasing_xp

@onready var ui: CanvasLayer = $UI
@onready var skill_animation: AnimatedSprite2D = %SkillAnimation
@onready var skills_menu: NinePatchRect = %SkillsMenu
@onready var skills_container: GridContainer = %SkillsContainer
@onready var weapon_sprite: Sprite2D = %WeaponSprite
@onready var error_sound: AudioStreamPlayer = %ErrorSound
@onready var experience_bar: TextureProgressBar = %ExperienceBar
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var level_up_sound: AudioStreamPlayer = %LevelUpSound

enum {
	RIGHT, DOWN, LEFT, UP
}

enum SelectionType {
	SINGLE_ENEMY,
	SINGLE_ALLY,
	ALL_ENEMIES,
	ALL_ALLIES,
	SELF,
}
const NO_SELECTION: Array[SelectionType] = [
	SelectionType.ALL_ENEMIES,
	SelectionType.ALL_ALLIES,
	SelectionType.SELF,
]
var _selection_type: SelectionType

# flags:
var _is_selecting := false
var played_turn := false

# stats:
var _data: AllyBattlerData
var _max_magic_points: int = 25
var _skills: Array[Skill]
var weapon: Weapon
var _magic_points: int
var levels_gained := 0

# Visuals:
var text_color: Color

# Skill stuff:
var _skill_to_perform: Skill
var _skill_selection_area: SkillSelectionArea

# Selection indices:
var _ally_selection_index := 0
var _enemy_selection_index := Vector2i.ZERO

# Battler arrays:
var targets: Array[Battler] = []

# Buffer stuff:
var _input_buffer_timer := 0.0
const _INPUT_DELAY := 0.05
var _buffered_index_offset := Vector2i.ZERO

func _ready() -> void:
	super._ready()
	ui.hide()
	experience_bar.hide()
	skills_menu.hide()
	animated_sprite_2d.play("idle right")
	experience_bar.max_value = _data.EXP_to_next_level
	experience_bar.value = _data.EXP
	weapon_sprite.texture = weapon.texture
	# Set up skills:
	populate_skills_menu()
	if _health <= 0:
		die()

func _on_skill_button_pressed(skill: Skill) -> void:
	if _magic_points < skill.magic_points_cost:
		%ErrorSound.play()
		return
	_skill_to_perform = skill
	if skill.selection_type in NO_SELECTION:
		skills_menu.hide()
		ui.hide()
		perform_action()
		return
	_is_selecting = true
	_selection_type = skill.selection_type
	skills_menu.hide()
	ui.hide()
	_ally_selection_index = 0
	_enemy_selection_index = Vector2.ZERO
	var target := get_main_target_battler()
	EventBus.set_cursor_visible.emit(true)
	EventBus.move_cursor_to.emit(target.global_position)
	update_battler_ui.emit(target)
	if skill.selection_area:
		var area: SkillSelectionArea = skill.selection_area.instantiate()
		add_child(area)
		_skill_selection_area = area
		_skill_selection_area.highlight_target(self, target)

func play_turn() -> void:
	await populate_skills_menu()
	ui.show()
	skills_menu.show()
	for child in skills_container.get_children():
		if child is BaseButton:
			child.grab_focus()
			break
	# cancel any guarding:
	self._defense = _data.defense

func populate_skills_menu() -> void:
	for child in skills_container.get_children():
		child.queue_free()
		await child.tree_exited
	
	for skill: Skill in _skills:
		var can_afford := skill.magic_points_cost < _magic_points
		var texture_rect := TextureRect.new()
		texture_rect.texture = skill.icon if can_afford else skill.disabled_icon
		skills_container.add_child(texture_rect)
		var label := Label.new()
		label.text = skill.name
		skills_container.add_child(label)
		var button := Button.new()
		button.custom_minimum_size.x = 36
		button.text = "%d MP" % skill.magic_points_cost
		button.disabled = not can_afford
		skills_container.add_child(button)
		button.pressed.connect(_on_skill_button_pressed.bind(skill))
		button.focus_entered.connect(func():
			skill_button_focused.emit(skill.magic_points_cost, _magic_points, _max_magic_points)
		)


func get_main_target_battler() -> Battler:
	match _selection_type:
		SelectionType.SELF:
			return self
		SelectionType.SINGLE_ALLY:
			return _allies[_ally_selection_index % _allies.size()]
		SelectionType.SINGLE_ENEMY:
			var enemy := _enemies_grid[_enemy_selection_index.x].elements[_enemy_selection_index.y]
			if enemy and enemy.is_alive:
				return enemy
			_enemy_selection_index.x = 0
			while _enemy_selection_index.x < _enemies_grid.size():
				_enemy_selection_index.y = 0
				while _enemy_selection_index.y < _enemies_grid[_enemy_selection_index.x].elements.size():
					enemy = _enemies_grid[_enemy_selection_index.x].elements[_enemy_selection_index.y]
					if enemy and enemy.is_alive:
						return enemy
					_enemy_selection_index.y += 1
				_enemy_selection_index.x += 1
			return enemy
		_:
			assert(false, "%s is unhandled case!" % SelectionType.keys()[_selection_type])
			return null

func perform_action() -> void:
	started_turn.emit()
	played_turn = true
	await get_tree().create_timer(0.1).timeout
	hide_stat_bars()
	_starting_pos = self.global_position
	_magic_points -= _skill_to_perform.magic_points_cost
	#if _skill_to_perform.battle_text:
		#EventBus.display_text.emit(_skill_to_perform.battle_text % get_colored_name())
		#await EventBus.textbox_closed
	var qte: QuickTimeEvent
	qte = _skill_to_perform.quick_time_event.instantiate()
	add_child(qte)
	qte.finished.connect(func():
		qte.queue_free()
		show_stat_bars()
		self.animated_sprite_2d.modulate.a = 0.75
		finished_turn.emit()
	)
	qte.start(self)

func _process(delta: float) -> void:
	
	if skills_menu.visible and Input.is_action_just_pressed("secondary action"):
		skills_menu.hide()
		cancel_my_turn.emit()
	
	if not _is_selecting or not Input.is_anything_pressed() or EventBus.is_cursor_moving:
		_input_buffer_timer = 0.0
		_buffered_index_offset = Vector2i.ZERO
		return
	
	# Cancel selection:
	if Input.is_action_just_pressed("secondary action"):
		_is_selecting = false
		skills_menu.show()
		ui.show()
		focus_on_first_skill_button()
		EventBus.move_cursor_to.emit(self.global_position)
		if _skill_selection_area:
			_skill_selection_area.queue_free()
	
	if _selection_type == SelectionType.SINGLE_ENEMY:
		var index_offset := Vector2i.ZERO
		if Input.is_action_pressed("move right"):
			index_offset.y = 1
		if Input.is_action_pressed("move left"):
			index_offset.y = -1
		if Input.is_action_pressed("move up"):
			index_offset.x = -1
		if Input.is_action_pressed("move down"):
			index_offset.x = 1
		
		if index_offset.x != 0:
			_buffered_index_offset.x = index_offset.x
		if index_offset.y != 0:
			_buffered_index_offset.y = index_offset.y
		
		_input_buffer_timer += delta
		if _input_buffer_timer >= _INPUT_DELAY:
			_input_buffer_timer = 0.0
			_buffered_index_offset = Vector2i.ZERO
			var enemy: EnemyBattler = null
			while (enemy == null) or (not enemy.is_alive):
				_enemy_selection_index += index_offset
				_enemy_selection_index %= _enemies_grid.size()
				enemy = _enemies_grid[_enemy_selection_index.x].elements[_enemy_selection_index.y]
			EventBus.move_cursor_to.emit(enemy.global_position)
			update_battler_ui.emit(enemy)
	
	elif _selection_type == SelectionType.SINGLE_ALLY:
		if Input.is_action_pressed("move right"):
			_ally_selection_index = 0
		if Input.is_action_pressed("move down"):
			_ally_selection_index = 1
		if Input.is_action_pressed("move left"):
			_ally_selection_index = 2
		if Input.is_action_pressed("move up"):
			_ally_selection_index = 3
		EventBus.move_cursor_to.emit(get_main_target_battler().global_position)
	
	if Input.is_action_pressed("primary action"):
		if not check_constraints():
			%ErrorSound.play()
			return
		EventBus.set_cursor_visible.emit(false)
		_is_selecting = false
		if _skill_selection_area:
			targets = _skill_selection_area.battlers.duplicate()
			_skill_selection_area.queue_free()
		ui.hide()
		perform_action()
	if _skill_selection_area:
		_skill_selection_area.highlight_target(self, get_main_target_battler())

func check_constraints() -> bool:
	var target := get_main_target_battler()
	for constraint in _skill_to_perform.constraints:
		match constraint:
			Skill.Constraints.TARGET_MUST_BE_ALIVE:
				if not target.is_alive:
					return false
			Skill.Constraints.TARGET_MUST_BE_DEAD:
				if target.is_alive:
					return false
			Skill.Constraints.TARGET_MUST_HAVE_PLAYED_TURN:
				if not (target as AllyBattler).played_turn:
					return false
	return true

func _on_view_skill_list_button_pressed() -> void:
	if _magic_points <= 0 or _skills.is_empty():
		%ErrorSound.play()
		return
	action_to_perform = ActionType.SKILL
	skills_menu.show()
	focus_on_first_skill_button()

func focus_on_first_skill_button():
	for child in skills_container.get_children():
		if child is BaseButton:
			child.grab_focus()
			scroll_container.set_deferred("scroll_vertical", 0)
			break

func increase_exp(amount: int) -> void:
	# We update stats first:
	_data.health =_health
	_data.magic_points =_magic_points
	_data.skills =_skills
	
	experience_bar.show()
	while amount > 0:
		experience_bar.max_value = _data.EXP_to_next_level
		experience_bar.value = _data.EXP
		var exp_left_to_next_level := _data.EXP_to_next_level - _data.EXP
		if amount < exp_left_to_next_level:
			# No level up:
			_data.EXP += amount
			var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(experience_bar,"value",_data.EXP,0.5)
			await tween.finished
			break
		else:
			# Level Up:
			levels_gained += 1
			amount -= exp_left_to_next_level
			_data.EXP = 0
			var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(experience_bar, "value", experience_bar.max_value, 0.5)
			tween.tween_property(experience_bar, "scale", Vector2.ONE*1.25, 0.1)
			tween.tween_property(experience_bar, "scale", Vector2.ONE, 0.2)
			await tween.finished
			_data.EXP_to_next_level *= 2
	finished_increasing_xp.emit()

func level_up() -> void:
	for i in levels_gained:
		level_up_sound.play()
		_data.level += 1
		var args := [get_colored_name(), _data.level]
		EventBus.display_text.emit("%s reached level %d" % args)
		await EventBus.textbox_closed
		# Check if reached max level:
		if _data.level-1 > len(_data.level_ups):
			return
		var level_up := _data.level_ups[_data.level-2]
		for stat: LevelUp.Stat in level_up.stat_increases.keys():
			var increase_amount: int = level_up.stat_increases[stat]
			var stat_string: String = LevelUp.Stat.keys()[stat]
			stat_string = stat_string.to_lower()
			#EventBus.display_text.emit(
				#"%s increased by %d" % [stat_string.replace('_',' '), increase_amount]
			#)
			#await EventBus.textbox_closed
			var original_value = _data.get(stat_string)
			_data.set(stat_string, original_value + increase_amount)
			if stat_string == "max_health":
				_data.health += increase_amount
			elif stat_string == 'max_magic_points':
				_data.magic_points += increase_amount
		for skill: Skill in level_up.skills:
			_data.skills.append(skill)
			EventBus.display_text.emit("New Skill Unlocked: %s" % Util.BBcode_color(skill.name, _data.text_color)) 
			await EventBus.textbox_closed

func missed_effect(pos: Vector2) -> void:
	const MISS_LABEL = preload("uid://cqw5qj1ygekwl")
	var label: MissLabel = MISS_LABEL.instantiate()
	add_child(label)
	label.global_position = pos
	await label.bouncing_finished
	%ErrorSound.play()
	await %ErrorSound.finished

func show_stat_bars() -> void:
	super.show_stat_bars()

func hide_stat_bars() -> void:
	super.hide_stat_bars()

func die() -> void:
	super.die()
	animated_sprite_2d.modulate.a = 0.75
	animated_sprite_2d.play("dead")

func get_colored_name() -> String:
	return Util.BBcode_color(battler_name, text_color)

func play_attack_anim() -> void:
	animated_sprite_2d.play("attack right")
	weapon_sprite.show()
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	var starting_pos := weapon_sprite.position
	tween.tween_property(weapon_sprite, "position", starting_pos+Vector2(5,0), 0.1)
	tween.tween_property(weapon_sprite, "position", starting_pos, 0.2)
	await tween.finished
	weapon_sprite.hide()
	animated_sprite_2d.play("idle right")

func stop_guarding() -> void:
	self._defense = _data.defense

func guard() -> void:
	self._defense *= 3

func play_moving_animation() -> void:
	animated_sprite_2d.play("walk right")

func stop_moving_animation():
	animated_sprite_2d.play("idle right")
