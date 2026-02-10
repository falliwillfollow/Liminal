extends StaticBody3D
class_name Door

@export var open_angle_degrees: float = 95.0
@export var open_direction: float = 1.0
@export var open_speed: float = 6.0
@export var auto_close_seconds: float = 0.0
@export var is_locked: bool = false

var _closed_y: float
var _target_y: float
var _is_open: bool = false
var _auto_close_timer: float = 0.0

func _ready() -> void:
    _closed_y = rotation.y
    _target_y = _closed_y

func interact(_actor: Node) -> void:
    if is_locked:
        return
    set_open_state(not _is_open)

func set_open_state(open_state: bool) -> void:
    if is_locked and open_state:
        return
    _is_open = open_state
    if _is_open:
        _target_y = _closed_y + deg_to_rad(open_angle_degrees) * open_direction
        _auto_close_timer = auto_close_seconds
    else:
        _target_y = _closed_y
        _auto_close_timer = 0.0

func unlock() -> void:
    is_locked = false

func lock() -> void:
    is_locked = true

func _physics_process(delta: float) -> void:
    rotation.y = lerp_angle(rotation.y, _target_y, clamp(open_speed * delta, 0.0, 1.0))

    if _is_open and auto_close_seconds > 0.0:
        _auto_close_timer -= delta
        if _auto_close_timer <= 0.0:
            _is_open = false
            _target_y = _closed_y
