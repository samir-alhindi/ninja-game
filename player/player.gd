class_name Player extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var attack_timer: Timer = %AttackTimer
@onready var weapon_sound: AudioStreamPlayer = %WeaponSound

@onready var weapon_down: Area2D = %WeaponDown
@onready var weapon_right: Area2D = %WeaponRight
@onready var weapon_left: Area2D = %WeaponLeft
@onready var weapon_up: Area2D = %WeaponUp

@export var movement_speed: int = 100
@export var attack_duration := 0.5
@export var health: int = 3
@export var strength: int = 1

class Direction:
	
	enum Directions {LEFT, RIGHT, UP, DOWN}
	var direction: Directions
	var vector: Vector2
	var string: String
	var current_weapon: Area2D
	
	func _init(direction: Directions, player: Player) -> void:
		self.direction = direction
		match direction:
			Directions.LEFT:
				vector = Vector2.LEFT
				string = "left"
				player.current_weapon = player.weapon_left
			Directions.RIGHT:
				vector = Vector2.RIGHT
				string = "right"
				player.current_weapon = player.weapon_right
			Directions.UP:
				vector = Vector2.UP
				string = "up"
				player.current_weapon = player.weapon_up
			Directions.DOWN:
				vector = Vector2.DOWN
				string = "down"
				player.current_weapon = player.weapon_down

var direction: Direction
var is_attacking := false
var current_weapon: Area2D

func _ready() -> void:
	direction = Direction.new(Direction.Directions.DOWN, self)

func _physics_process(delta: float) -> void:
	if not is_attacking:
		movement_logic_and_animation(delta)
	attack_logic_and_animation(delta)
	move_and_slide()

func movement_logic_and_animation(_delta: float) -> void:
	
	var idle: bool = false
	if Input.is_action_pressed("move right"):
		direction = Direction.new(Direction.Directions.RIGHT, self)
	elif Input.is_action_pressed("move left"):
		direction = Direction.new(Direction.Directions.LEFT, self)
	elif Input.is_action_pressed("move up"):
		direction = Direction.new(Direction.Directions.UP, self)
	elif Input.is_action_pressed("move down"):
		direction = Direction.new(Direction.Directions.DOWN, self)
	else:
		velocity = Vector2.ZERO
		idle = true
	
	var animation_name: String
	if idle:
		animation_name = "idle %s" % direction.string
	else:
		animation_name = "walk %s" % direction.string
		velocity = direction.vector * movement_speed
	animated_sprite_2d.play(animation_name)

func attack_logic_and_animation(_delta: float) -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		velocity = Vector2.ZERO
		var animation_name := "attack %s" % direction.string
		animated_sprite_2d.play(animation_name)
		weapon_sound.play()
		
		current_weapon.show()
		set_weapon_disabled(false)
		attack_timer.start(attack_duration)

func _on_attack_timer_timeout() -> void:
	is_attacking = false
	current_weapon.hide()
	set_weapon_disabled(true)

func _on_damageable_component_took_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()

func set_weapon_disabled(disabled: bool) -> void:
	(current_weapon.get_node("CollisionShape2D") as CollisionShape2D).disabled = disabled

func _on_weapon_area_entered(area: Area2D) -> void:
	if area is KnockbackCompnent:
		area.knockback(direction.vector, 100, 0.25)
	if area is DamageComponent:
		area.take_damage(strength)
