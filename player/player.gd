class_name Player extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var weapon_sound: AudioStreamPlayer = %WeaponSound
@onready var hearts_container: HBoxContainer = %HeartsContainer
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var hurt_sound: AudioStreamPlayer = %HurtSound
@onready var knockback_component: KnockbackCompnent = %KnockbackComponent
@onready var debug_label: Label = %DebugLabel

@onready var weapon_down: PlayerWeapon = %WeaponDown
@onready var weapon_right: PlayerWeapon = %WeaponRight
@onready var weapon_left: PlayerWeapon = %WeaponLeft
@onready var weapon_up: PlayerWeapon = %WeaponUp

@export var movement_speed: int = 100
@export var attack_duration := 0.5
@export var health: int = 3: set = set_health
@export var strength: int = 1

class Direction:
	
	enum Directions {LEFT, RIGHT, UP, DOWN}
	var direction: Directions
	var vector: Vector2
	var string: String
	var current_weapon: Area2D
	
	func _init(dir: Directions, player: Player) -> void:
		self.direction = dir
		match dir:
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
var current_weapon: PlayerWeapon

func _ready() -> void:
	direction = Direction.new(Direction.Directions.DOWN, self)
	set_health(health)

func _physics_process(delta: float) -> void:
	if not is_attacking:
		movement_logic_and_animation(delta)
	attack_logic_and_animation(delta)
	move_and_slide()

func movement_logic_and_animation(_delta: float) -> void:
	
	var input_vector = Input.get_vector("move left", "move right","move up", "move down")
	velocity = input_vector * movement_speed + knockback_component.force
	
	if input_vector.x > 0:
		direction = Direction.new(Direction.Directions.RIGHT, self)
	if input_vector.x < 0:
		direction = Direction.new(Direction.Directions.LEFT, self)
	if input_vector.y > 0:
		direction = Direction.new(Direction.Directions.DOWN, self)
	if input_vector.y < 0:
		direction = Direction.new(Direction.Directions.UP, self)
	
	var animation_name: String
	if input_vector == Vector2.ZERO:
		animation_name = "idle %s" % direction.string
	else:
		animation_name = "walk %s" % direction.string
	animated_sprite_2d.play(animation_name)

func attack_logic_and_animation(_delta: float) -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		velocity = Vector2.ZERO
		var animation_name := "attack %s" % direction.string
		animated_sprite_2d.play(animation_name)
		weapon_sound.play()
		
		current_weapon.slash()
		await current_weapon.finished_slashing
		is_attacking = false

func _on_damageable_component_took_damage(amount: int) -> void:
	health -= amount
	animation_player.play("hurt")
	hurt_sound.play()
	if health <= 0:
		queue_free()

func _on_weapon_area_entered(area: Area2D) -> void:
	if area is KnockbackCompnent:
		var dir := global_position.direction_to(area.global_position)
		area.knockback(dir, 100)
	if area is DamageComponent:
		area.take_damage(strength)

func set_health(new_val) -> void:
	health = new_val
	for child: Node in hearts_container.get_children():
		child.queue_free()
	for i in range(health):
		const HEART_SPRITE := preload("uid://b5g33wvjhrwnt")
		var sprite: TextureRect = HEART_SPRITE.instantiate()
		hearts_container.add_child(sprite)
