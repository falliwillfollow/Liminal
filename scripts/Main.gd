extends Node3D

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var player: Node = $Player
@onready var liminal_level: Node = $LiminalLevel

var atmosphere_director: AtmosphereDirector
const MENU_SCENE := "res://scenes/Menu.tscn"
const TROPICAL_BEACH_LEVEL_SCENE := preload("res://scenes/TropicalBeachLevel.tscn")
var _loading_layer: CanvasLayer
var _loading_progress_bar: ProgressBar
var _loading_title_label: Label
var _loading_status_label: Label
var _is_loading_world := true
var _is_transitioning_to_beach := false
var _is_returning_to_menu := false
const DEBUG_SPAWN_IN_UNDERGROUND_ROOM := false

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _ensure_arrow_bindings()
    _ensure_pause_menu_binding()
    _apply_sky_art()
    _set_player_enabled(false)
    _create_loading_ui()
    _connect_world_build_signals()

    atmosphere_director = AtmosphereDirector.new()
    add_child(atmosphere_director)
    atmosphere_director.setup(world_environment)

func _ensure_arrow_bindings() -> void:
    _bind_key_to_action("move_forward", KEY_UP)
    _bind_key_to_action("move_backward", KEY_DOWN)
    _bind_key_to_action("move_left", KEY_LEFT)
    _bind_key_to_action("move_right", KEY_RIGHT)

func _ensure_pause_menu_binding() -> void:
    if not InputMap.has_action("pause_menu"):
        InputMap.add_action("pause_menu")
    _bind_key_to_action("pause_menu", KEY_ESCAPE)

func _unhandled_input(event: InputEvent) -> void:
    if _is_loading_world:
        if event.is_action_pressed("pause_menu"):
            get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("pause_menu"):
        if player and player.has_method("is_in_numpad_focus") and player.is_in_numpad_focus():
            player.exit_numpad_focus()
            get_viewport().set_input_as_handled()
            return
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        get_tree().change_scene_to_file(MENU_SCENE)

func _bind_key_to_action(action: StringName, keycode: int) -> void:
    if not InputMap.has_action(action):
        return

    for event in InputMap.action_get_events(action):
        if event is InputEventKey and event.keycode == keycode:
            return

    var key_event := InputEventKey.new()
    key_event.keycode = keycode
    InputMap.action_add_event(action, key_event)

func _apply_sky_art() -> void:
    var env := world_environment.environment
    if env == null:
        return

    var procedural := ProceduralSkyMaterial.new()
    procedural.sky_top_color = Color(0.31, 0.5, 0.74, 1.0)
    procedural.sky_horizon_color = Color(0.84, 0.69, 0.49, 1.0)
    procedural.ground_bottom_color = Color(0.11, 0.1, 0.1, 1.0)
    procedural.sun_angle_max = 16.0
    procedural.sun_curve = 0.13

    var sky := Sky.new()
    sky.sky_material = procedural

    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.volumetric_fog_enabled = true
    env.volumetric_fog_density = 0.0015
    env.volumetric_fog_albedo = Color(0.95, 0.86, 0.74, 1.0)

    _spawn_volumetric_clouds()

func _spawn_volumetric_clouds() -> void:
    var old := get_node_or_null("VolumetricClouds")
    if old:
        old.queue_free()

    var cloud_root := Node3D.new()
    cloud_root.name = "VolumetricClouds"
    add_child(cloud_root)

    var rng := RandomNumberGenerator.new()
    rng.seed = 9007

    for i in range(24):
        var cloud := FogVolume.new()
        cloud.position = Vector3(
            rng.randf_range(-120.0, 120.0),
            rng.randf_range(18.0, 32.0),
            rng.randf_range(-140.0, 140.0)
        )
        cloud.rotation = Vector3(
            rng.randf_range(-0.03, 0.03),
            rng.randf_range(0.0, TAU),
            rng.randf_range(-0.03, 0.03)
        )
        cloud.size = Vector3(
            rng.randf_range(18.0, 44.0),
            rng.randf_range(4.0, 9.0),
            rng.randf_range(14.0, 40.0)
        )

        var material := FogMaterial.new()
        material.albedo = Color(0.98, 0.95, 0.88, 1.0)
        material.density = rng.randf_range(0.02, 0.045)
        material.edge_fade = 0.18
        cloud.material = material

        cloud_root.add_child(cloud)

func _create_loading_ui() -> void:
    _loading_layer = CanvasLayer.new()
    _loading_layer.name = "LoadingLayer"
    add_child(_loading_layer)

    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _loading_layer.add_child(root)

    var fade := ColorRect.new()
    fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    fade.color = Color(0.03, 0.03, 0.04, 0.7)
    root.add_child(fade)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(520, 140)
    center.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    panel.add_child(vbox)

    _loading_title_label = Label.new()
    _loading_title_label.text = "Loading Liminal"
    _loading_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(_loading_title_label)

    _loading_status_label = Label.new()
    _loading_status_label.text = "Initializing..."
    _loading_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(_loading_status_label)

    _loading_progress_bar = ProgressBar.new()
    _loading_progress_bar.min_value = 0.0
    _loading_progress_bar.max_value = 100.0
    _loading_progress_bar.value = 1.0
    _loading_progress_bar.show_percentage = true
    _loading_progress_bar.custom_minimum_size = Vector2(480, 28)
    vbox.add_child(_loading_progress_bar)

func _connect_world_build_signals() -> void:
    if liminal_level == null:
        _finish_world_loading()
        return

    _connect_runtime_level_signals(liminal_level)

    if liminal_level.has_signal("world_build_progress"):
        liminal_level.connect("world_build_progress", Callable(self, "_on_world_build_progress"))
    if liminal_level.has_signal("world_build_completed"):
        liminal_level.connect("world_build_completed", Callable(self, "_on_world_build_completed"))
    else:
        _finish_world_loading()

func _connect_runtime_level_signals(level: Node) -> void:
    if level == null:
        return
    if level.has_signal("beach_transition_requested"):
        var callback := Callable(self, "_on_beach_transition_requested")
        if not level.is_connected("beach_transition_requested", callback):
            level.connect("beach_transition_requested", callback)
    if level.has_signal("sunset_completed"):
        var sunset_callback := Callable(self, "_on_sunset_completed")
        if not level.is_connected("sunset_completed", sunset_callback):
            level.connect("sunset_completed", sunset_callback)

func _on_world_build_progress(progress: float, status: String) -> void:
    if _loading_progress_bar:
        _loading_progress_bar.value = clampf(progress * 100.0, 0.0, 100.0)
    if _loading_status_label:
        _loading_status_label.text = status

func _on_world_build_completed() -> void:
    _on_world_build_progress(1.0, "Ready")
    _move_player_to_underground_room()
    _finish_world_loading()

func _finish_world_loading() -> void:
    if not _is_loading_world:
        return
    _is_loading_world = false
    _set_player_enabled(true)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if _loading_layer:
        _loading_layer.queue_free()
        _loading_layer = null

func _set_player_enabled(enabled: bool) -> void:
    if player == null:
        return
    player.set_physics_process(enabled)
    player.set_process_input(enabled)
    player.set_process_unhandled_input(enabled)

func _on_beach_transition_requested() -> void:
    if _is_transitioning_to_beach:
        return
    _is_transitioning_to_beach = true
    _swap_to_tropical_beach_map()

func _swap_to_tropical_beach_map() -> void:
    var previous_level := liminal_level
    if previous_level:
        previous_level.queue_free()

    var beach_level := TROPICAL_BEACH_LEVEL_SCENE.instantiate()
    add_child(beach_level)
    liminal_level = beach_level
    _connect_runtime_level_signals(liminal_level)
    _apply_tropical_beach_sky()
    _move_player_to_level_spawn(liminal_level)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_tropical_beach_sky() -> void:
    var env := world_environment.environment
    if env:
        var procedural := ProceduralSkyMaterial.new()
        procedural.sky_top_color = Color(0.24, 0.39, 0.63, 1.0)
        procedural.sky_horizon_color = Color(1.0, 0.63, 0.37, 1.0)
        procedural.ground_bottom_color = Color(0.16, 0.12, 0.08, 1.0)
        procedural.sun_angle_max = 18.0
        procedural.sun_curve = 0.11

        var sky := Sky.new()
        sky.sky_material = procedural
        env.background_mode = Environment.BG_SKY
        env.sky = sky
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(1.0, 0.76, 0.55, 1.0)
        env.ambient_light_energy = 0.55
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = 0.0009
        env.volumetric_fog_albedo = Color(1.0, 0.72, 0.47, 1.0)

    if sun_light:
        sun_light.light_color = Color(1.0, 0.72, 0.48)
        sun_light.light_energy = 1.25
        sun_light.shadow_enabled = true
        sun_light.global_position = Vector3(0.0, 36.0, 18.0)
        sun_light.look_at(Vector3(0.0, 6.0, 220.0), Vector3.UP)

func _move_player_to_level_spawn(level: Node) -> void:
    if player == null or level == null:
        return
    if not level.has_method("get_spawn_data"):
        return

    var spawn_data: Dictionary = level.get_spawn_data()
    var spawn_position: Vector3 = spawn_data.get("position", Vector3.ZERO)
    var look_target: Vector3 = spawn_data.get("look_target", spawn_position + Vector3.FORWARD)
    if player.has_method("focus_viewpoint"):
        player.focus_viewpoint(spawn_position, look_target)
        return

    if player is Node3D:
        (player as Node3D).global_position = spawn_position

func _on_sunset_completed() -> void:
    if _is_returning_to_menu:
        return
    _is_returning_to_menu = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    call_deferred("_return_to_main_menu")

func _return_to_main_menu() -> void:
    get_tree().change_scene_to_file(MENU_SCENE)

func _move_player_to_underground_room() -> void:
    if not DEBUG_SPAWN_IN_UNDERGROUND_ROOM:
        return
    if player == null or liminal_level == null:
        return
    if not liminal_level.has_method("get_space4_room_spawn_data"):
        return

    var spawn_data: Dictionary = liminal_level.get_space4_room_spawn_data()
    if not bool(spawn_data.get("ready", false)):
        return

    var spawn_position: Vector3 = spawn_data.get("position", Vector3.ZERO)
    var look_target: Vector3 = spawn_data.get("look_target", spawn_position + Vector3.FORWARD)
    if player is CharacterBody3D:
        var body := player as CharacterBody3D
        body.global_position = spawn_position
        body.velocity = Vector3.ZERO
        var look_flat := Vector3(look_target.x, spawn_position.y, look_target.z)
        if spawn_position.distance_to(look_flat) > 0.001:
            body.look_at(look_flat, Vector3.UP)
            body.rotation.x = 0.0
            body.rotation.z = 0.0

        var head := body.get_node_or_null("Head")
        if head is Node3D:
            (head as Node3D).rotation.x = 0.0
    elif player is Node3D:
        (player as Node3D).global_position = spawn_position
