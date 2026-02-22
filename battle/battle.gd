class_name Battle extends Node2D

@onready var battlers: Node2D = %Battlers
@onready var text_box: ColorRect = %TextBox
@onready var battle_text: Label = %BattleText
@onready var player_battler: PlayerBattler = %PlayerBattler
@onready var enemy_battler: EnemyBattler = %EnemyBattler
@onready var battle_camera: Camera2D = %BattleCamera

signal textbox_closed
signal battle_finished

var enemy_data: BattlerData

func _ready() -> void:
	battle_camera.make_current()
	enemy_battler.init_self(enemy_data)
	text_box.hide()
	
	while not is_battle_finished():
		await get_tree().create_timer(0.1).timeout
		for battler: Battler in battlers.get_children():
			battler.decide_action()
			if battler is PlayerBattler:
				await battler.finished_deciding_action
		
		for battler: Battler in battlers.get_children():
			display_text(battler.action_text)
			await self.textbox_closed
			text_box.hide()
			battler.perform_action()
			await battler.finished_performing_action
			if is_battle_finished():
				break
	finish_battle()

func display_text(text: String) -> void:
	$DisplayTextSound.play()
	text_box.show()
	battle_text.text = text

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		textbox_closed.emit()

func is_battle_finished() -> bool:
	return not enemy_battler or not player_battler

func finish_battle() -> void:
	if not enemy_battler:
		display_text("Player Won !")
	else:
		display_text("Game Over...")
	await self.textbox_closed
	battle_finished.emit()
