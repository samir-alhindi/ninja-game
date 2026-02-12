class_name Player extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var attack_timer: Timer = %AttackTimer

@onready var weapon_down: Area2D = %WeaponDown
@onready var weapon_right: Area2D = %WeaponRight
@onready var weapon_left: Area2D = %WeaponLeft
@onready var weapon_up: Area2D = %WeaponUp

@export var movement_speed: int = 100
@export var attack_duration := 0.5

enum Direction {LEFT, RIGHT, UP, DOWN}

var last_direction: Direction = Direction.DOWN
var directions: Dictionary[Direction, String] = {
	Direction.LEFT : "left",
	Direction.RIGHT : "right",
	Direction.UP : "up",
	Direction.DOWN : "down"
}
var is_attacking := false
var current_weapon: DamagingComponent

func _physics_process(delta: float) -> void:
	if not is_attacking:
		movement_logic_and_animation(delta)
	attack_logic_and_animation(delta)
	move_and_slide()

func movement_logic_and_animation(_delta: float) -> void:
	var input_vector: Vector2
	
	if Input.is_action_pressed("move right"):
		input_vector = Vector2.RIGHT
		last_direction = Direction.RIGHT
	elif Input.is_action_pressed("move left"):
		input_vector = Vector2.LEFT
		last_direction = Direction.LEFT
	elif Input.is_action_pressed("move up"):
		input_vector = Vector2.UP
		last_direction = Direction.UP
	elif Input.is_action_pressed("move down"):
		input_vector = Vector2.DOWN
		last_direction = Direction.DOWN
	else:
		input_vector = Vector2.ZERO
	
	velocity = input_vector * movement_speed
	
	var animation_name: String
	if input_vector == Vector2.ZERO:
		animation_name = "idle %s" % directions[last_direction]
	else:
		animation_name = "walk %s" % directions[last_direction]
	animated_sprite_2d.play(animation_name)

func attack_logic_and_animation(_delta: float) -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		velocity = Vector2.ZERO
		var animation_name := "attack %s" % directions[last_direction]
		animated_sprite_2d.play(animation_name)
		
		match last_direction:
			Direction.UP:
				current_weapon = weapon_up
			Direction.DOWN:
				current_weapon = weapon_down
			Direction.LEFT:
				current_weapon = weapon_left
			Direction.RIGHT:
				current_weapon = weapon_right
		current_weapon.show()
		current_weapon.disabled = false
		attack_timer.start(attack_duration)

func _on_attack_timer_timeout() -> void:
	is_attacking = false
	current_weapon.hide()
	current_weapon.disabled = true


func _on_damageable_component_took_damage(amount: int) -> void:
	queue_free()
