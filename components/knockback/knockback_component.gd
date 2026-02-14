class_name KnockbackCompnent extends Area2D

var force := Vector2.ZERO

func knockback(direction: Vector2, knockback_force: int) -> void:
	force = direction * knockback_force

func _physics_process(delta: float) -> void:
	force = force.move_toward(Vector2.ZERO, delta * 200)
