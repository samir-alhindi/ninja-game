extends ColorRect

@onready var grid_container: GridContainer = $VBoxContainer/GridContainer
@onready var retro_button: Button = %RetroButton
@onready var modern_button: Button = %ModernButton
@onready var menu_sound: AudioStreamPlayer = %MenuSound
@onready var confirm_sound: AudioStreamPlayer = %ConfirmSound

func update_labels(scheme: MyInput.KeyboardMode, function: Callable) -> void:
	var nodes := grid_container.get_children()
	var starting_index := (
		1 if scheme == MyInput.KeyboardMode.RETRO else 2
	)
	for i in range(starting_index, len(nodes), 3):
		var label := nodes[i] as RichTextLabel
		if not label:
			continue
		function.call(label)

func _ready() -> void:
	var format_then_darken := func(label: RichTextLabel):
		Util.format_button_icons_to_rich_text_label(label)
		darken(label)
	MyInput.current_keyboard_mode = MyInput.KeyboardMode.RETRO
	update_labels(MyInput.KeyboardMode.RETRO, format_then_darken)
	MyInput.current_keyboard_mode = MyInput.KeyboardMode.MODERN
	update_labels(MyInput.KeyboardMode.MODERN, format_then_darken)
	retro_button.grab_focus()

func darken(node: CanvasItem) -> void:
	node.modulate.a = 0.5

func brighten(node: CanvasItem) -> void:
	node.modulate.a = 1.0

func _on_retro_button_focus_entered() -> void:
	menu_sound.play()
	update_labels(MyInput.KeyboardMode.RETRO, brighten)
	update_labels(MyInput.KeyboardMode.MODERN, darken)

func _on_modern_button_focus_entered() -> void:
	menu_sound.play()
	update_labels(MyInput.KeyboardMode.MODERN, brighten)
	update_labels(MyInput.KeyboardMode.RETRO, darken)

func _on_retro_button_pressed() -> void:
	MyInput.current_keyboard_mode = MyInput.KeyboardMode.RETRO
	finish()

func _on_modern_button_pressed() -> void:
	MyInput.current_keyboard_mode = MyInput.KeyboardMode.MODERN
	finish()

func finish() -> void:
	confirm_sound.play()
	for key in [KEY_SPACE, KEY_ENTER]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_erase_event("ui_accept", event)
	MyInput.update_keyboard_controls()
	MyInput.input_mode_changed.emit()
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	get_tree().change_scene_to_file("uid://ffwpq180qldq")
