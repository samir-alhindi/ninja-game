class_name FollowerEnemy extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var knockback_timer: Timer = %KnockbackTimer
@onready var hurt_sound: AudioStreamPlayer = %HurtSound
@onready var animation_player: AnimationPlayer = %AnimationPlayer

@export var movement_speed: int = 20
@export var health: int = 3
@export var strength: int = 1

const DIRECTIONS := [Vector2.UP, Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.ZERO]
var getting_knocked_back: bool = false
var player: Player

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if not getting_knocked_back:
		if not player:
			return
		var target_direction := self.global_position.direction_to(player.global_position)
		velocity = target_direction * movement_speed
	move_and_slide()
	
	if velocity.x > 0:
		animated_sprite_2d.play("walk right")
	elif velocity.x < 0:
		animated_sprite_2d.play("walk left")
	
	elif velocity.y > 0:
		animated_sprite_2d.play("walk down")
	elif velocity.y < 0:
		animated_sprite_2d.play("walk up")


func _on_damageable_component_took_damage(amount: int) -> void:
	animation_player.play("hurt")
	hurt_sound.play()
	health -= amount
	if health <= 0:
		queue_free()

func _on_knockback_component_knocked_back(direction: Vector2, force: int ,duration: float)-> void:
	getting_knocked_back = true
	knockback_timer.start(duration)
	velocity = direction * force
	move_and_slide()

func _on_knockback_timer_timeout() -> void:
	getting_knocked_back = false
	velocity = Vector2.ZERO

func _on_hit_box_area_entered(area: Area2D) -> void:
	if area is DamageComponent:
		area.take_damage(strength)
	if area is KnockbackCompnent:
		area.knockback(self.global_position.direction_to(area.global_position), 200, 0.25)
