class_name EnemyBattler extends Battler

func _ready() -> void:
	super._ready()

func decide_action() -> void:
	action_name = "attack"
	action_text = "Slime Jumped at green ninja"

func perform_action() -> void:
	if action_name == "attack":
		health_bar.hide()
		var final_pos := player().global_position + Vector2(25, 0)
		var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "global_position", final_pos, 0.5)
		await tween.finished
		animated_sprite_2d.play("attack")
		await animated_sprite_2d.animation_finished
		await player().take_damage(self.strength)
		animated_sprite_2d.play("idle")
		tween = create_tween().set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "global_position", starting_pos, 0.5)
		await tween.finished
		health_bar.show()
		finished_performing_action.emit()

func take_damage(amount: int) -> void:
	health -= amount
	damage_label.show()
	damage_label.text = str(amount)
	%HurtSound.play()
	%HurtAnimationPlayer.play("hurt")
	await %HurtAnimationPlayer.animation_finished
	damage_label.hide()
	if health <= 0:
		queue_free()

func player() -> PlayerBattler:
	return get_tree().get_first_node_in_group("player")
