@abstract
class_name Battler extends Area2D

signal started_turn
signal finished_turn
signal died
signal update_battler_ui(battler: Battler)

@export var movement_speed := 0.5

@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var health_bar: TextureProgressBar = %HealthBar
@onready var number_label: Label = %NumberLabel
@onready var hp_label: Label = $HPLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var selection_arrow_animation_player: AnimationPlayer = %SelectionArrowAnimationPlayer
@onready var selection_arrow: Sprite2D = %SelectionArrow
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

class Row:
	var elements: Array[EnemyBattler]

enum ActionType {ATTACK, SKILL, ROTATE}
var action_to_perform: ActionType

@warning_ignore_start("unused_private_class_variable")
var _action_text: String

# stats:
var _max_health: int = 100
var _strength: int = 25
var _defense: int = 20
var _speed: int = 20
var _health: int

# visuals:
var battler_name: String
var _sprite_frames: SpriteFrames
var _animation_speed: float = 5.0
var _starting_pos: Vector2
var portrait: Texture

# flags:
var _is_valid_instance := false
var is_alive := true

# Other"
var _target: Battler
var _enemies_grid: Array[EnemyBattlerRow]
var _allies: Array[AllyBattler]

static func create(data: BattlerData) -> Battler:
	var battler: Battler
	if data is AllyBattlerData:
		var ALLY_BATTLER := load("uid://l44h5nb2ub5t")
		battler = ALLY_BATTLER.instantiate() as AllyBattler
		battler._data = data
		battler._health = data.health
		battler._max_magic_points = data.max_magic_points
		battler._magic_points = data.magic_points
		battler._skills = data.skills
		battler.text_color = data.text_color
		battler.weapon = data.weapon
	elif data is EnemyBattlerData:
		var ENEMY_BATTLER = load("uid://b2i8v282cle12")
		battler = ENEMY_BATTLER.instantiate() as EnemyBattler
		battler._health = data.max_health
	else:
		assert(false, "undefined case...")
	battler._is_valid_instance = true
	battler._max_health = data.max_health
	battler._strength = data.strength
	battler._defense = data.defense
	battler._speed = data.speed
	battler._sprite_frames = data.sprite_frames
	battler._animation_speed = data.animation_speed
	battler.battler_name = data.name
	battler.portrait = data.portrait
	return battler

func _ready() -> void:
	assert(_is_valid_instance, "create a battler using the static create() method")
	number_label.hide()
	animated_sprite_2d.sprite_frames = _sprite_frames
	health_bar.max_value = _max_health
	set_health(_health)

func select_me() -> void:
	EventBus.move_cursor_to.emit(self.global_position)

@abstract
func play_turn() -> void

func die() -> void:
	is_alive = false
	died.emit()

func take_damage(battler_strength: int, skill_multiplier: float=1) -> void:
	var amount: int = max(1, round(battler_strength * skill_multiplier - _defense))
	set_health(_health - amount)
	%HurtSound.play()
	bounce_number_label(amount)
	if _health > 0:
		animation_player.play("hurt")
		await animation_player.animation_finished
	else:
		die()

func heal(amount: int) -> void:
	set_health(_health + amount)
	%HealSound.play()
	var current_alpha := animated_sprite_2d.modulate.a
	animation_player.play("hurt")
	await animation_player.animation_finished
	animated_sprite_2d.modulate.a = current_alpha
	await bounce_number_label(amount)

func bounce_number_label(amount: int) -> void:
	number_label.show()
	number_label.text = "%d" % amount
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(number_label, "scale", Vector2.ONE*1.5, 0.1)
	tween.tween_property(number_label, "scale", Vector2.ONE, 0.25)
	await tween.finished
	number_label.hide()

func set_health(new_val: int) -> void:
	_health = clamp(new_val, 0, _max_health)
	health_bar.value = new_val

func show_stat_bars() -> void:
	health_bar.show()

func hide_stat_bars() -> void:
	health_bar.hide()

func play_blinking_animation() -> void:
	animation_player.play("blink")

func stop_blinking_animation() -> void:
	animation_player.stop()

func play_selection_animation() -> void:
	selection_arrow.show()
	selection_arrow_animation_player.play("select")

func stop_selection_animation() -> void:
	selection_arrow.hide()
	selection_arrow_animation_player.stop()

func move_to(pos: Vector2, play_animation:=true) -> void:
	if play_animation:
		play_moving_animation()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "global_position", pos, movement_speed)
	await tween.finished
	if play_animation:
		stop_moving_animation()

func has_full_health() -> bool:
	return _health == _max_health

@abstract
func play_moving_animation() -> void

@abstract
func stop_moving_animation()
