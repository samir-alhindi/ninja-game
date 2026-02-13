class_name KnockbackCompnent extends Area2D

signal knocked_back(direction: Vector2, force: int, duration: float)

func knockback(direction: Vector2, force: int, duration: float) -> void:
	knocked_back.emit(direction, force, duration)
