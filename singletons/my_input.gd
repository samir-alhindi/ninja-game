extends Node

@onready var button_icon_data: Dictionary[String, ButtonIconData] = {
	"[PRIMARY]" : preload("uid://djmypdcxk76p3"),
	"[SECONDARY]" : preload("uid://cxx1mamkhfdvv"),
	"[TERTIARY]" : preload("uid://4bsv61q0xkto"),
	"[LEFT]" : preload("uid://kwucpuslu335"),
	"[RIGHT]" : preload("uid://b516xopujv2mv"),
	"[UP]" : preload("uid://0cvik7g4vy4w"),
	"[DOWN]" : preload("uid://cupb7isnibpnc"),
}

class KeyboardAction:
	var name: String
	var retro_event: InputEventKey
	var modern_event: InputEventKey
	
	func _init(name: String, retro_key: Key, modern_key: Key) -> void:
		self.name = name
		retro_event = InputEventKey.new()
		retro_event.physical_keycode = retro_key
		modern_event = InputEventKey.new()
		modern_event.physical_keycode = modern_key

var keyboard_actions: Array[KeyboardAction] = [
	KeyboardAction.new("move left", KEY_LEFT, KEY_A),
	KeyboardAction.new("move right",  KEY_RIGHT, KEY_D),
	KeyboardAction.new("move up", KEY_UP, KEY_W),
	KeyboardAction.new("move down", KEY_DOWN, KEY_S),
	KeyboardAction.new("primary action", KEY_Z, KEY_E),
	KeyboardAction.new("secondary action", KEY_X, KEY_Q),
	KeyboardAction.new("tertiary action", KEY_C, KEY_TAB),
	KeyboardAction.new("ui_left", KEY_LEFT, KEY_A),
	KeyboardAction.new("ui_right",  KEY_RIGHT, KEY_D),
	KeyboardAction.new("ui_up", KEY_UP, KEY_W),
	KeyboardAction.new("ui_down", KEY_DOWN, KEY_S),
	KeyboardAction.new("ui_accept", KEY_Z, KEY_E),
]

signal input_mode_changed

enum InputMode {
	KEYBOARD,
	PLAYSTATION,
	XBOX,
	NINTENDO,
}

enum KeyboardMode {
	RETRO,
	MODERN,
}

var current_input_mode := InputMode.KEYBOARD
var current_keyboard_mode := KeyboardMode.RETRO

func get_sprite_frames(button_icon_data: ButtonIconData) -> SpriteFrames:
	match current_input_mode:
		InputMode.KEYBOARD:
			return (
				button_icon_data.modern_keyboard_sprite_frames
				if current_keyboard_mode == KeyboardMode.MODERN
				else button_icon_data.retro_keyboard_sprite_frames
			)
		InputMode.PLAYSTATION:
			return button_icon_data.playstation_sprite_frames
		InputMode.NINTENDO:
			return button_icon_data.nintendo_sprite_frames
		_:
			return button_icon_data.xbox_sprite_frames

func get_icon(tag: String) -> Texture:
	return get_sprite_frames(button_icon_data[tag]).get_frame_texture("default", 0)

func _input(event: InputEvent) -> void:
	var new_input_mode: InputMode
	if event is InputEventKey:
		new_input_mode = InputMode.KEYBOARD
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var name := Input.get_joy_name(event.device).to_lower()
		if "nintendo" in name or "switch" in name or "joy-con"  in name:
			new_input_mode = InputMode.NINTENDO
		elif "sony" in name or "dualshock" in name or "dualsense" in name or "ps5" in name or "ps4" in name or "ps3" in name:
			new_input_mode = InputMode.PLAYSTATION
		else:
			new_input_mode = InputMode.XBOX
	
	if new_input_mode != current_input_mode:
		current_input_mode = new_input_mode
		input_mode_changed.emit()

func update_keyboard_controls() -> void:
	for action in keyboard_actions:
		if current_keyboard_mode == KeyboardMode.RETRO:
			InputMap.action_erase_event(action.name, action.modern_event)
		else:
			InputMap.action_erase_event(action.name, action.retro_event)
