extends StaticBody3D
class_name NumpadButton

@export var key_value: String = "0"
@export var numpad_path: NodePath

func press_button(_actor: Node) -> void:
    var numpad := get_node_or_null(numpad_path)
    if numpad == null:
        numpad = get_parent()
    if numpad and numpad.has_method("press_key"):
        numpad.press_key(key_value)
