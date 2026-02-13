class_name DamageComponent extends Area2D

signal took_damage(amount: int)

func take_damage(amount: int) -> void:
	took_damage.emit(amount)
