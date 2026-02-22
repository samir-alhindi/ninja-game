class_name Enemy extends CharacterBody2D

@onready var direction_change_timer: Timer = %DirectionChangeTimer
@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var knockback_timer: Timer = %KnockbackTimer
@onready var hurt_sound: AudioStreamPlayer = %HurtSound
@onready var animation_player: AnimationPlayer = %AnimationPlayer

@export var battle_data: BattlerData
@export var movement_speed: int = 100
@export var health: int = 3
@export var strength: int = 1

@export_category("direction change")
@export var min_direction_change_time: float = 5.0
@export var max_direction_change_time: float = 20.0

const DIRECTIONS := [Vector2.UP, Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT]
var direction: Vector2
var getting_knocked_back: bool = false

func _ready() -> void:
	direction = DIRECTIONS.pick_random()
	direction_change_timer.start(direction_change_time())

func _physics_process(_delta: float) -> void:
	velocity = direction * movement_speed
	move_and_slide()
	
	match direction:
		Vector2.UP:
			animated_sprite_2d.play("walk up")
		Vector2.DOWN:
			animated_sprite_2d.play("walk down")
		Vector2.RIGHT:
			animated_sprite_2d.play("walk right")
		Vector2.LEFT:
			animated_sprite_2d.play("walk left")
		_:
			animated_sprite_2d.stop()

func _on_direction_change_timer_timeout() -> void:
	direction = DIRECTIONS.pick_random()
	direction_change_timer.start(direction_change_time())

func direction_change_time() -> float:
	return randf_range(min_direction_change_time, max_direction_change_time)

func die() -> void:
	set_physics_process(false)
	for i in range(6):
		animation_player.play("hurt")
		await animation_player.animation_finished
	queue_free()
