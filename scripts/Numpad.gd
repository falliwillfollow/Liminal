extends StaticBody3D
class_name Numpad

const KEYPAD_CLICK_AUDIO_PATH := "res://assets/sounds/keypad/switch_on.wav"
const KEYPAD_SUCCESS_AUDIO_PATH := "res://assets/sounds/keypad/confirm.wav"
const KEYPAD_ERROR_AUDIO_PATH := "res://assets/sounds/keypad/error.wav"

signal code_accepted(numpad: Numpad)

@export var required_code: String = "1973"
@export var max_digits: int = 6
@export var unlock_target_paths: Array[NodePath] = []
@export var open_targets_on_success: bool = true

var _buffer: String = ""
var _display_label: Label3D
var _display_mesh: MeshInstance3D
var _runtime_unlock_targets: Array[Node] = []
var _key_audio_player: AudioStreamPlayer3D
var _status_audio_player: AudioStreamPlayer3D
var _key_click_stream: AudioStream
var _success_stream: AudioStream
var _error_stream: AudioStream
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _display_label = get_node_or_null("DisplayLabel")
    _display_mesh = get_node_or_null("DisplayMesh")
    _rng.randomize()
    _setup_audio()
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
    _play_key_click()
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
        code_accepted.emit(self)
        _play_status_sound(true)
        _show_status("OPEN", Color(0.45, 1.0, 0.45))
    else:
        _play_status_sound(false)
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

func _setup_audio() -> void:
    _key_click_stream = _load_audio_stream(KEYPAD_CLICK_AUDIO_PATH)
    _success_stream = _load_audio_stream(KEYPAD_SUCCESS_AUDIO_PATH)
    _error_stream = _load_audio_stream(KEYPAD_ERROR_AUDIO_PATH)

    _key_audio_player = AudioStreamPlayer3D.new()
    _key_audio_player.name = "KeyAudioPlayer"
    _key_audio_player.volume_db = -9.0
    _key_audio_player.stream = _key_click_stream
    add_child(_key_audio_player)

    _status_audio_player = AudioStreamPlayer3D.new()
    _status_audio_player.name = "StatusAudioPlayer"
    _status_audio_player.volume_db = -6.0
    add_child(_status_audio_player)

func _play_key_click() -> void:
    if _key_audio_player == null or _key_click_stream == null:
        return
    _key_audio_player.pitch_scale = _rng.randf_range(0.95, 1.06)
    _key_audio_player.play()

func _play_status_sound(is_success: bool) -> void:
    if _status_audio_player == null:
        return
    var stream := _success_stream if is_success else _error_stream
    if stream == null:
        return
    _status_audio_player.stream = stream
    _status_audio_player.pitch_scale = _rng.randf_range(0.98, 1.03)
    _status_audio_player.play()

func _load_audio_stream(path: String) -> AudioStream:
    var stream: Resource = null
    if ResourceLoader.exists(path):
        stream = ResourceLoader.load(path)
    if stream is AudioStream:
        return stream as AudioStream

    if not FileAccess.file_exists(path):
        push_warning("Numpad sound file not found: %s" % path)
        return null

    var lower := path.to_lower()
    if lower.ends_with(".wav"):
        return AudioStreamWAV.load_from_file(path)
    if lower.ends_with(".ogg"):
        return AudioStreamOggVorbis.load_from_file(path)
    if lower.ends_with(".mp3"):
        var bytes := FileAccess.get_file_as_bytes(path)
        if bytes.is_empty():
            return null
        var mp3 := AudioStreamMP3.new()
        mp3.data = bytes
        return mp3
    return null
