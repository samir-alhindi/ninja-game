class_name PlayerWeapon extends Node2D

signal finished_slashing
signal area_entered(area: Area2D)

@onready var animation_player: AnimationPlayer = %AnimationPlayer

func slash() -> void:
	animation_player.play("slash")
	await animation_player.animation_finished
	finished_slashing.emit()

func _on_area_2d_area_entered(area: Area2D) -> void:
	area_entered.emit(area)
