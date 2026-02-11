extends StaticBody3D
class_name Door

const DOOR_OPEN_AUDIO_PATH := "res://assets/sounds/doors/open.wav"
const DOOR_CLOSE_AUDIO_PATH := "res://assets/sounds/doors/close.wav"
const DOOR_LOCKED_AUDIO_PATH := "res://assets/sounds/doors/locked.wav"

@export var open_angle_degrees: float = 95.0
@export var open_direction: float = 1.0
@export var open_speed: float = 6.0
@export var auto_close_seconds: float = 0.0
@export var is_locked: bool = false

var _closed_y: float
var _target_y: float
var _is_open: bool = false
var _auto_close_timer: float = 0.0
var _door_audio_player: AudioStreamPlayer3D
var _open_stream: AudioStream
var _close_stream: AudioStream
var _locked_stream: AudioStream
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _closed_y = rotation.y
    _target_y = _closed_y
    _rng.randomize()
    _setup_audio()

func interact(_actor: Node) -> void:
    if is_locked:
        _play_door_sound(_locked_stream, 0.97, 1.04)
        return
    set_open_state(not _is_open)

func set_open_state(open_state: bool) -> void:
    if is_locked and open_state:
        return
    if _is_open == open_state:
        return
    _is_open = open_state
    if _is_open:
        _target_y = _closed_y + deg_to_rad(open_angle_degrees) * open_direction
        _auto_close_timer = auto_close_seconds
        _play_door_sound(_open_stream, 0.95, 1.03)
    else:
        _target_y = _closed_y
        _auto_close_timer = 0.0
        _play_door_sound(_close_stream, 0.96, 1.02)

func unlock() -> void:
    is_locked = false

func lock() -> void:
    is_locked = true

func _physics_process(delta: float) -> void:
    rotation.y = lerp_angle(rotation.y, _target_y, clamp(open_speed * delta, 0.0, 1.0))

    if _is_open and auto_close_seconds > 0.0:
        _auto_close_timer -= delta
        if _auto_close_timer <= 0.0:
            set_open_state(false)

func _setup_audio() -> void:
    _open_stream = _load_audio_stream(DOOR_OPEN_AUDIO_PATH)
    _close_stream = _load_audio_stream(DOOR_CLOSE_AUDIO_PATH)
    _locked_stream = _load_audio_stream(DOOR_LOCKED_AUDIO_PATH)

    _door_audio_player = AudioStreamPlayer3D.new()
    _door_audio_player.name = "DoorAudioPlayer"
    _door_audio_player.volume_db = -6.0
    add_child(_door_audio_player)

func _play_door_sound(stream: AudioStream, pitch_min: float, pitch_max: float) -> void:
    if _door_audio_player == null or stream == null:
        return
    _door_audio_player.stream = stream
    _door_audio_player.pitch_scale = _rng.randf_range(pitch_min, pitch_max)
    _door_audio_player.play()

func _load_audio_stream(path: String) -> AudioStream:
    var stream: Resource = null
    if ResourceLoader.exists(path):
        stream = ResourceLoader.load(path)
    if stream is AudioStream:
        return stream as AudioStream

    if not FileAccess.file_exists(path):
        push_warning("Door sound file not found: %s" % path)
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
