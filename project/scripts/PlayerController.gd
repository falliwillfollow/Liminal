extends CharacterBody3D

@export var walk_speed: float = 3.8
@export var sprint_speed: float = 5.3
@export var acceleration: float = 16.0
@export var air_control: float = 4.0
@export var gravity: float = 24.0
@export var jump_velocity: float = 4.8
@export var look_sensitivity: float = 0.0025
@export var max_pitch_degrees: float = 85.0

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

var _pitch_radians: float = 0.0

func _ready() -> void:
    _pitch_radians = head.rotation.x
    floor_snap_length = 0.35
    floor_max_angle = deg_to_rad(60.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * look_sensitivity)
        _pitch_radians = clamp(_pitch_radians - event.relative.y * look_sensitivity, deg_to_rad(-max_pitch_degrees), deg_to_rad(max_pitch_degrees))
        head.rotation.x = _pitch_radians

    if event.is_action_pressed("toggle_mouse_capture"):
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        else:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
    var move_basis := global_transform.basis
    var move_direction := (move_basis.x * input_vector.x) + (-move_basis.z * input_vector.y)
    move_direction = move_direction.normalized()

    var target_speed := walk_speed
    if Input.is_key_pressed(KEY_SHIFT):
        target_speed = sprint_speed

    var target_velocity := move_direction * target_speed
    var control := acceleration if is_on_floor() else air_control

    velocity.x = move_toward(velocity.x, target_velocity.x, control * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, control * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("ui_accept"):
        velocity.y = jump_velocity

    move_and_slide()

    if Input.is_action_just_pressed("interact"):
        _try_interact()

func _try_interact() -> void:
    interaction_ray.force_raycast_update()
    if not interaction_ray.is_colliding():
        return

    var collider := interaction_ray.get_collider()
    if collider and collider.has_method("interact"):
        collider.interact(self)
