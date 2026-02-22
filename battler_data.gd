@tool
class_name BattlerData extends Resource

@export var name: String
@export var max_health: int
@export var speed: int
@export var strength: int
@export var sprite_frames: SpriteFrames
@export_tool_button("create animations template") var button = create_animations_template

func create_animations_template() -> void:
	sprite_frames = SpriteFrames.new()
	const ANIMATION_NAMES := ["idle", "attack"]
	for n: String in ANIMATION_NAMES:
		sprite_frames.add_animation(n)
