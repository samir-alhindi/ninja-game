@abstract
class_name Battler extends Node2D

signal finished_performing_action

@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var health_bar: ProgressBar = %HealthBar
@onready var damage_label: Label = %DamageLabel

@export var data: BattlerData

var health: int: set = set_health
var max_health: int
var speed: int
var strength: int

var action_name: String
var action_text: String
var starting_pos: Vector2

func _ready() -> void:
	starting_pos = self.global_position
	damage_label.hide()

func init_self(data: BattlerData) -> void:
	self.data = data
	max_health = data.max_health
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = max_health
	strength = data.strength
	speed = data.speed
	animated_sprite_2d.sprite_frames = data.sprite_frames
	animated_sprite_2d.play("idle")

@abstract
func decide_action() -> void

@abstract
func perform_action() -> void

@abstract
func take_damage(amount: int) -> void

func set_health(new_val: int) -> void:
	health = new_val
	health_bar.value = health
