class_name PlayerBattler extends Battler

@onready var ui: CanvasLayer = $UI
@onready var attack_button: Button = %AttackButton

signal finished_deciding_action

var is_attacking := false

func _ready() -> void:
	super._ready()
	init_self(self.data)
	ui.hide()
	$AttackBar.hide()

func decide_action() -> void:
	ui.show()
	attack_button.grab_focus()

func perform_action() -> void:
	if action_name == "attack":
		health_bar.hide()
		var final_pos := enemy().global_position - Vector2(25, 0)
		var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "global_position", final_pos, 0.5)
		await tween.finished
		$AttackBar.show()
		%AttackAnimationPlayer.play("attack")
		is_attacking = true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and is_attacking:
		is_attacking = false
		animated_sprite_2d.play("attack")
		%Sword.show()
		%AttackAnimationPlayer.stop(true)
		var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(%AttackSlider, "scale", Vector2.ONE*1.5, 0.1)
		tween.tween_property(%AttackSlider, "scale", Vector2.ONE, 0.25)
		await tween.finished
		var distance_to_center: int = round(abs(%AttackSlider.position.x - 50))
		var multiplier: float
		if distance_to_center == 0:
			multiplier = 1.0
		elif distance_to_center < 10:
			multiplier = 0.9
		elif distance_to_center < 20:
			multiplier = 0.75
		elif distance_to_center < 30:
			multiplier = 0.5
		else:
			multiplier = 0.25
		var damage: int = round(data.strength * multiplier)
		await enemy().take_damage(damage)
		
		$AttackBar.hide()
		animated_sprite_2d.play("idle")
		%Sword.hide()
		tween = create_tween().set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "global_position", starting_pos, 0.5)
		await tween.finished
		health_bar.show()
		finished_performing_action.emit()

func _on_attack_button_pressed() -> void:
	action_name = "attack"
	action_text = "Green Ninja slashed the enemy !"
	ui.hide()
	finished_deciding_action.emit()

func enemy() -> EnemyBattler:
	return get_tree().get_first_node_in_group("enemy")

func take_damage(amount: int) -> void:
	%HurtSound.play()
	%HurtAnimationPlayer.play("hurt")
	health -= amount
	await %HurtAnimationPlayer.animation_finished

func _on_attack_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		is_attacking = false
		$AttackBar.hide()
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "global_position", starting_pos, 0.5)
		await tween.finished
		health_bar.show()
		finished_performing_action.emit()
