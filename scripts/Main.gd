extends Node3D

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var player: Node = $Player
@onready var liminal_level: Node = $LiminalLevel

var atmosphere_director: AtmosphereDirector
const MENU_SCENE := "res://scenes/Menu.tscn"
var _loading_layer: CanvasLayer
var _loading_progress_bar: ProgressBar
var _loading_title_label: Label
var _loading_status_label: Label
var _is_loading_world := true

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

    if liminal_level.has_signal("world_build_progress"):
        liminal_level.connect("world_build_progress", Callable(self, "_on_world_build_progress"))
    if liminal_level.has_signal("world_build_completed"):
        liminal_level.connect("world_build_completed", Callable(self, "_on_world_build_completed"))
    else:
        _finish_world_loading()

func _on_world_build_progress(progress: float, status: String) -> void:
    if _loading_progress_bar:
        _loading_progress_bar.value = clampf(progress * 100.0, 0.0, 100.0)
    if _loading_status_label:
        _loading_status_label.text = status

func _on_world_build_completed() -> void:
    _on_world_build_progress(1.0, "Ready")
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
