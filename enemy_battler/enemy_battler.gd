class_name EnemyBattler extends Battler

func _ready() -> void:
	super._ready()
	animated_sprite_2d.play("idle left")

func play_turn() -> void:
	EventBus.set_cursor_visible.emit(true)
	EventBus.move_cursor_to.emit(self.global_position)
	action_to_perform = ActionType.ATTACK
	if action_to_perform == ActionType.ATTACK:
		
		var rng := RandomNumberGenerator.new()
		var weights := [2.0, 1.0, 0.5, 1.0]
		var living_allies: Array[AllyBattler] = _allies.duplicate()
		var i := len(living_allies) - 1
		while i >= 0:
			if not living_allies[i].is_alive:
				living_allies.remove_at(i)
				weights.remove_at(i)
			i -= 1
		var ally := living_allies[rng.rand_weighted(weights)]
		
		#var args := [battler_name, ally.get_colored_name()]
		#EventBus.display_text.emit("%s attacked %s" % args)
		#await EventBus.textbox_closed
		EventBus.set_cursor_visible.emit(false)
		health_bar.hide()
		_starting_pos = self.global_position
		await move_to(ally.global_position + Vector2(25, 0))
		animated_sprite_2d.play("attack")
		await animated_sprite_2d.animation_finished
		await ally.take_damage(_strength, 1)
		animated_sprite_2d.play("idle left")
		await move_to(_starting_pos)
		health_bar.show()
		finished_turn.emit()

func die() -> void:
	super.die()
	collision_shape_2d.set_deferred("disabled", true)
	create_tween().tween_property(self, "modulate:a", 0.0, 0.5)

func play_moving_animation() -> void:
	animated_sprite_2d.play("walk left")

func stop_moving_animation():
	animated_sprite_2d.play("idle left")
