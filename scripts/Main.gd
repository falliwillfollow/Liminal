extends Node3D

@onready var world_environment: WorldEnvironment = $WorldEnvironment

var atmosphere_director: AtmosphereDirector
const MENU_SCENE := "res://scenes/Menu.tscn"

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _ensure_arrow_bindings()
    _ensure_pause_menu_binding()
    _apply_sky_art()

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
    if event.is_action_pressed("pause_menu"):
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
