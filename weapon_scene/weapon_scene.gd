class_name WeaponScene extends Area2D

@onready var collision_shape_2d: CollisionShape2D = %CollisionShape2D

func set_hitbox(disabled: bool) -> void:
	collision_shape_2d.disabled = disabled
