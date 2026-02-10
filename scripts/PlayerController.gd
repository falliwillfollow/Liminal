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
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

var _pitch_radians: float = 0.0
var _focused_numpad: Node3D = null
var _default_fov: float = 78.0
var _saved_focus_transform: Transform3D
var _saved_focus_pitch: float = 0.0
var _has_saved_focus_pose: bool = false

func _ready() -> void:
    _pitch_radians = head.rotation.x
    _default_fov = camera.fov
    floor_snap_length = 0.35
    floor_max_angle = deg_to_rad(60.0)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause_menu") and _focused_numpad != null:
        exit_numpad_focus()
        get_viewport().set_input_as_handled()
        return

    if _focused_numpad != null and event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            _try_click_focused_numpad(mouse_event.position)
            get_viewport().set_input_as_handled()
            return

    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * look_sensitivity)
        _pitch_radians = clamp(_pitch_radians - event.relative.y * look_sensitivity, deg_to_rad(-max_pitch_degrees), deg_to_rad(max_pitch_degrees))
        head.rotation.x = _pitch_radians

func _physics_process(delta: float) -> void:
    var input_vector := Vector2.ZERO if _focused_numpad != null else Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
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
    elif _focused_numpad == null and Input.is_action_just_pressed("ui_accept"):
        velocity.y = jump_velocity

    move_and_slide()

    if _focused_numpad == null and Input.is_action_just_pressed("interact"):
        _try_interact()

func _try_interact() -> void:
    interaction_ray.force_raycast_update()
    if not interaction_ray.is_colliding():
        return

    var collider := interaction_ray.get_collider()
    if collider and collider.has_method("interact"):
        collider.interact(self)

func enter_numpad_focus(numpad: Node3D) -> void:
    if numpad == null:
        return
    if not _has_saved_focus_pose:
        _saved_focus_transform = global_transform
        _saved_focus_pitch = _pitch_radians
        _has_saved_focus_pose = true
    _focused_numpad = numpad
    _move_to_numpad_focus_pose()
    _center_camera_on_numpad()
    camera.fov = 48.0
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if _focused_numpad.has_method("on_focus_entered"):
        _focused_numpad.on_focus_entered(self)

func exit_numpad_focus() -> void:
    if _focused_numpad and _focused_numpad.has_method("on_focus_exited"):
        _focused_numpad.on_focus_exited(self)
    _focused_numpad = null
    if _has_saved_focus_pose:
        global_transform = _saved_focus_transform
        _pitch_radians = _saved_focus_pitch
        head.rotation.x = _pitch_radians
        _has_saved_focus_pose = false
    velocity = Vector3.ZERO
    camera.fov = _default_fov
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func is_in_numpad_focus() -> bool:
    return _focused_numpad != null

func _try_click_focused_numpad(mouse_position: Vector2) -> void:
    if _focused_numpad == null:
        return

    var from := camera.project_ray_origin(mouse_position)
    var to := from + camera.project_ray_normal(mouse_position) * 6.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collide_with_areas = false
    query.collide_with_bodies = true
    query.collision_mask = 1
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return

    var collider: Object = hit.get("collider")
    if collider == null:
        return
    if not (collider is Node):
        return
    var clicked_node := collider as Node
    if not _belongs_to_focused_numpad(clicked_node):
        return
    if clicked_node.has_method("press_button"):
        clicked_node.press_button(self)

func _belongs_to_focused_numpad(node: Node) -> bool:
    var current: Node = node
    while current != null:
        if current == _focused_numpad:
            return true
        current = current.get_parent()
    return false

func _center_camera_on_numpad() -> void:
    if _focused_numpad == null:
        return

    var target := _get_numpad_focus_target()

    var body_target := Vector3(target.x, global_position.y, target.z)
    if global_position.distance_to(body_target) > 0.001:
        look_at(body_target, Vector3.UP)
        rotation.x = 0.0
        rotation.z = 0.0

    var cam_to_target := target - camera.global_position
    var flat_distance := Vector2(cam_to_target.x, cam_to_target.z).length()
    if flat_distance <= 0.001:
        _pitch_radians = 0.0
    else:
        _pitch_radians = clamp(
            -atan2(cam_to_target.y, flat_distance),
            deg_to_rad(-max_pitch_degrees),
            deg_to_rad(max_pitch_degrees)
        )
    head.rotation.x = _pitch_radians

func _move_to_numpad_focus_pose() -> void:
    if _focused_numpad == null:
        return

    var target := _get_numpad_focus_target()
    var outward := -_focused_numpad.global_transform.basis.z
    outward.y = 0.0
    if outward.length_squared() < 0.0001:
        outward = -global_transform.basis.z
        outward.y = 0.0
    outward = outward.normalized()

    var desired_camera_pos := target + outward * 0.95 + Vector3(0.0, 0.03, 0.0)
    var body_pos := desired_camera_pos - Vector3(0.0, head.position.y, 0.0)
    global_position = body_pos
    velocity = Vector3.ZERO

func _get_numpad_focus_target() -> Vector3:
    var target := _focused_numpad.global_position
    var focus_node := _focused_numpad.get_node_or_null("FocusPoint")
    if focus_node is Node3D:
        target = (focus_node as Node3D).global_position
    return target
