extends StaticBody3D
class_name Numpad

@export var required_code: String = "1973"
@export var max_digits: int = 6
@export var unlock_target_paths: Array[NodePath] = []
@export var open_targets_on_success: bool = true

var _buffer: String = ""
var _display_label: Label3D
var _display_mesh: MeshInstance3D
var _runtime_unlock_targets: Array[Node] = []

func _ready() -> void:
    _display_label = get_node_or_null("DisplayLabel")
    _display_mesh = get_node_or_null("DisplayMesh")
    _refresh_display()

func interact(actor: Node) -> void:
    if actor and actor.has_method("enter_numpad_focus"):
        actor.enter_numpad_focus(self)

func on_focus_entered(_actor: Node) -> void:
    if _display_mesh:
        var mat := _display_mesh.material_override as StandardMaterial3D
        if mat:
            mat.emission_enabled = true
            mat.emission = Color(0.22, 0.48, 0.2)

func on_focus_exited(_actor: Node) -> void:
    if _display_mesh:
        var mat := _display_mesh.material_override as StandardMaterial3D
        if mat:
            mat.emission_enabled = true
            mat.emission = Color(0.12, 0.24, 0.12)

func press_key(key_value: String) -> void:
    match key_value:
        "C":
            _buffer = ""
            _refresh_display()
        "E":
            if _buffer.length() > 0:
                _submit_code()
        _:
            if _buffer.length() < max_digits:
                _buffer += key_value
                _refresh_display()

func _submit_code() -> void:
    var entered := _buffer
    _buffer = ""
    if entered == required_code:
        _unlock_targets()
        _show_status("OPEN", Color(0.45, 1.0, 0.45))
    else:
        _show_status("ERR", Color(1.0, 0.35, 0.35))

func _refresh_display() -> void:
    if _display_label == null:
        return
    _display_label.text = _buffer if _buffer.length() > 0 else "-"
    _display_label.modulate = Color(0.68, 1.0, 0.66)

func _show_status(text: String, color: Color) -> void:
    if _display_label == null:
        return
    _display_label.text = text
    _display_label.modulate = color
    _restore_display_after_delay()

func _restore_display_after_delay() -> void:
    await get_tree().create_timer(0.75).timeout
    _refresh_display()

func _unlock_targets() -> void:
    var targets: Array[Node] = []
    var seen_ids: Dictionary = {}

    for target_path in unlock_target_paths:
        var from_path := get_node_or_null(target_path)
        if from_path and not seen_ids.has(from_path.get_instance_id()):
            seen_ids[from_path.get_instance_id()] = true
            targets.append(from_path)

    for runtime_target in _runtime_unlock_targets:
        if runtime_target and not seen_ids.has(runtime_target.get_instance_id()):
            seen_ids[runtime_target.get_instance_id()] = true
            targets.append(runtime_target)

    for target in targets:
        if target.has_method("unlock"):
            target.unlock()
        if open_targets_on_success and target.has_method("set_open_state"):
            target.set_open_state(true)

func register_unlock_target(target: Node) -> void:
    if target == null:
        return
    _runtime_unlock_targets.append(target)
