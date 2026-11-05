class_name InputSetup
extends RefCounted
## Registers the demo's input actions at runtime, so the project works without
## any hand-edited InputMap entries. Want to rebind keys? Change the table below
## (or delete this file and define the same action names in Project Settings >
## Input Map; the other scripts only look the actions up by name).

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"emote_wave": [KEY_F],
	"emote_dance": [KEY_G],
	"next_character": [KEY_C],
	"camera_left": [KEY_Q],
	"camera_right": [KEY_E],
}


static func register() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: int in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)
