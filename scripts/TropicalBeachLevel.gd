extends Node3D

const BEACH_BENCH_SCRIPT := preload("res://scripts/BeachBench.gd")
const BENCH_AUDIO_PATH := "res://assets/sounds/2-18-25v5.mp3"

signal sunset_completed

@onready var geometry_root: Node3D = $GeometryRoot

@export var sunset_duration_seconds := 180.0

var _sun_disk: MeshInstance3D
var _sun_material: StandardMaterial3D
var _sun_light: DirectionalLight3D
var _world_environment: WorldEnvironment
var _sunset_progress := 0.0
var _sunset_done_emitted := false
var _bench_audio_player: AudioStreamPlayer
var _bench_audio_started := false
var _bench_audio_fade_started := false
var _bench_audio_fade_duration := 6.0

func _ready() -> void:
    _setup_bench_audio()
    _build_beach()
    _capture_runtime_scene_refs()
    _apply_sunset_state(0.0)

func _process(delta: float) -> void:
    if _sun_disk == null:
        return
    var duration := maxf(sunset_duration_seconds, 1.0)
    _sunset_progress = minf(_sunset_progress + delta / duration, 1.0)
    _apply_sunset_state(_sunset_progress)
    _update_bench_audio_fade(delta)
    if _sunset_progress >= 1.0 and not _sunset_done_emitted:
        _sunset_done_emitted = true
        sunset_completed.emit()

func get_spawn_data() -> Dictionary:
    return {
        "position": Vector3(0.0, 1.05, 10.8),
        "look_target": Vector3(0.0, 1.2, 120.0)
    }

func _build_beach() -> void:
    var sand := Color(0.9, 0.8, 0.58)
    var wet_sand := Color(0.74, 0.63, 0.46)
    var dune := Color(0.67, 0.58, 0.41)
    # Pull shoreline much closer to player so ocean dominates the view.
    _spawn_box(Vector3(0.0, -0.3, -16.0), Vector3(320.0, 0.6, 74.0), sand, true)
    _spawn_box(Vector3(0.0, -0.2, 24.0), Vector3(320.0, 0.2, 8.0), wet_sand, true)
    _spawn_box(Vector3(0.0, 0.62, -48.0), Vector3(220.0, 2.0, 86.0), dune, true)
    _spawn_box(
        Vector3(0.0, -0.28, 120.0),
        Vector3(400.0, 0.16, 184.0),
        Color(0.22, 0.49, 0.68),
        false,
        _make_water_material()
    )
    # Opaque far-ocean slab so the sun can sink behind the horizon line.
    _spawn_box(
        Vector3(0.0, -0.285, 520.0),
        Vector3(900.0, 0.12, 640.0),
        Color(0.18, 0.43, 0.6),
        false,
        _make_horizon_water_material()
    )

    var bench := _spawn_bench(Vector3(0.0, 0.0, 19.0), 0.0)
    if bench and bench.has_signal("sat_down"):
        var callback := Callable(self, "_on_bench_sat_down")
        if not bench.is_connected("sat_down", callback):
            bench.connect("sat_down", callback)
    _spawn_sun_disk(Vector3(0.0, 38.0, 520.0))

func _spawn_bench(position: Vector3, yaw_degrees: float) -> StaticBody3D:
    var bench := StaticBody3D.new()
    bench.position = position
    bench.rotation_degrees.y = yaw_degrees
    bench.set_script(BEACH_BENCH_SCRIPT)
    bench.set("seat_offset", Vector3(0.0, 0.86, 0.26))
    bench.set("look_offset", Vector3(0.0, 1.05, 60.0))

    var interaction_collision := CollisionShape3D.new()
    var interaction_shape := BoxShape3D.new()
    interaction_shape.size = Vector3(2.8, 1.45, 1.2)
    interaction_collision.shape = interaction_shape
    interaction_collision.position = Vector3(0.0, 0.72, 0.18)
    bench.add_child(interaction_collision)

    var wood_mat := StandardMaterial3D.new()
    wood_mat.albedo_color = Color(0.47, 0.31, 0.2)
    wood_mat.roughness = 0.9
    wood_mat.metallic = 0.0
    wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

    var metal_mat := StandardMaterial3D.new()
    metal_mat.albedo_color = Color(0.13, 0.16, 0.2)
    metal_mat.roughness = 0.8
    metal_mat.metallic = 0.1
    metal_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

    _add_bench_part(bench, Vector3(0.0, 0.72, 0.2), Vector3(2.4, 0.12, 0.72), wood_mat)
    _add_bench_part(bench, Vector3(0.0, 1.06, -0.08), Vector3(2.4, 0.58, 0.12), wood_mat)
    _add_bench_part(bench, Vector3(-1.06, 0.4, 0.18), Vector3(0.12, 0.7, 0.7), metal_mat)
    _add_bench_part(bench, Vector3(1.06, 0.4, 0.18), Vector3(0.12, 0.7, 0.7), metal_mat)

    geometry_root.add_child(bench)
    return bench

func _setup_bench_audio() -> void:
    if not ResourceLoader.exists(BENCH_AUDIO_PATH) and not FileAccess.file_exists(BENCH_AUDIO_PATH):
        push_warning("Bench audio not found at %s" % BENCH_AUDIO_PATH)
        return
    var stream := ResourceLoader.load(BENCH_AUDIO_PATH)
    if not (stream is AudioStream):
        # Fallback: decode MP3 directly from bytes even if import metadata is missing.
        var bytes := FileAccess.get_file_as_bytes(BENCH_AUDIO_PATH)
        if bytes.is_empty():
            push_warning("Bench audio file is empty or unreadable: %s" % BENCH_AUDIO_PATH)
            return
        var mp3 := AudioStreamMP3.new()
        mp3.data = bytes
        stream = mp3

    _bench_audio_player = AudioStreamPlayer.new()
    _bench_audio_player.name = "BenchAudioPlayer"
    _bench_audio_player.stream = stream as AudioStream
    _bench_audio_player.volume_db = 0.0
    add_child(_bench_audio_player)

func _on_bench_sat_down(_bench: Node, _actor: Node) -> void:
    if _bench_audio_player == null:
        push_warning("Bench sat down, but audio player is not initialized.")
        return
    if _bench_audio_started:
        return
    _bench_audio_started = true
    _bench_audio_fade_started = false
    _bench_audio_player.volume_db = 0.0
    _bench_audio_player.play()

func _update_bench_audio_fade(delta: float) -> void:
    if _bench_audio_player == null:
        return
    if not _bench_audio_player.playing:
        return
    if _bench_audio_player.stream == null:
        return

    var stream_len := _bench_audio_player.stream.get_length()
    if stream_len <= 0.0:
        return

    var fade_start_time := maxf(stream_len - _bench_audio_fade_duration, 0.0)
    if _bench_audio_player.get_playback_position() < fade_start_time:
        return

    _bench_audio_fade_started = true
    var fade_step := (56.0 / maxf(_bench_audio_fade_duration, 0.01)) * delta
    _bench_audio_player.volume_db = maxf(_bench_audio_player.volume_db - fade_step, -60.0)

func _add_bench_part(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)

func _spawn_sun_disk(position: Vector3) -> void:
    var sun := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 20.0
    mesh.height = 40.0
    mesh.radial_segments = 20
    mesh.rings = 10
    sun.mesh = mesh
    sun.position = position
    sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var sun_mat := StandardMaterial3D.new()
    sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sun_mat.albedo_color = Color(1.0, 0.74, 0.39)
    sun_mat.emission_enabled = true
    sun_mat.emission = Color(1.0, 0.55, 0.22)
    sun_mat.emission_energy_multiplier = 1.8
    sun_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sun_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    sun.material_override = sun_mat
    _sun_material = sun_mat
    _sun_disk = sun
    geometry_root.add_child(sun)

func _capture_runtime_scene_refs() -> void:
    var parent := get_parent()
    if parent == null:
        return
    var light_node := parent.get_node_or_null("DirectionalLight3D")
    if light_node is DirectionalLight3D:
        _sun_light = light_node as DirectionalLight3D
    var env_node := parent.get_node_or_null("WorldEnvironment")
    if env_node is WorldEnvironment:
        _world_environment = env_node as WorldEnvironment

func _apply_sunset_state(progress: float) -> void:
    var t := _smoothstep(clampf(progress, 0.0, 1.0))
    var sink_t := _smoothstep(clampf((t - 0.72) / 0.28, 0.0, 1.0))
    var sun_alpha := 1.0 - sink_t

    if _sun_disk:
        _sun_disk.position = Vector3(
            0.0,
            lerpf(38.0, -30.0, t),
            lerpf(520.0, 620.0, t)
        )

    if _sun_material:
        var sun_albedo := Color(1.0, 0.74, 0.39).lerp(Color(1.0, 0.42, 0.18), t)
        sun_albedo.a = sun_alpha
        _sun_material.albedo_color = sun_albedo
        _sun_material.emission = Color(1.0, 0.55, 0.22).lerp(Color(1.0, 0.32, 0.12), t)
        _sun_material.emission_energy_multiplier = lerpf(1.9, 0.12, t) * (1.0 - sink_t * 0.85)

    if _sun_light and _sun_disk:
        # Keep directional light vector collinear with the visible sun disk.
        _sun_light.global_position = _sun_disk.global_position
        _sun_light.look_at(Vector3(0.0, 1.8, 19.0), Vector3.UP)
        _sun_light.light_color = Color(1.0, 0.72, 0.48).lerp(Color(1.0, 0.44, 0.21), t)
        _sun_light.light_energy = lerpf(1.25, 0.07, t) * (1.0 - sink_t * 0.7)

    if _world_environment and _world_environment.environment:
        var env := _world_environment.environment
        env.ambient_light_color = Color(1.0, 0.76, 0.55).lerp(Color(0.95, 0.43, 0.24), t)
        env.ambient_light_energy = lerpf(0.56, 0.3, t)
        env.volumetric_fog_albedo = Color(1.0, 0.72, 0.47).lerp(Color(0.96, 0.41, 0.25), t)
        env.volumetric_fog_density = lerpf(0.0009, 0.00135, t)

        if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
            var sky_material := env.sky.sky_material as ProceduralSkyMaterial
            sky_material.sky_top_color = Color(0.24, 0.39, 0.63).lerp(Color(0.14, 0.19, 0.33), t)
            sky_material.sky_horizon_color = Color(1.0, 0.63, 0.37).lerp(Color(1.0, 0.36, 0.2), t)
            sky_material.ground_bottom_color = Color(0.16, 0.12, 0.08).lerp(Color(0.1, 0.07, 0.06), t)

func _smoothstep(x: float) -> float:
    var y := clampf(x, 0.0, 1.0)
    return y * y * (3.0 - 2.0 * y)

func _make_water_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.17, 0.44, 0.62, 0.97)
    material.roughness = 0.15
    material.metallic = 0.0
    material.emission_enabled = true
    material.emission = Color(0.1, 0.22, 0.35)
    material.emission_energy_multiplier = 0.18
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    return material

func _make_horizon_water_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.16, 0.4, 0.58, 1.0)
    material.roughness = 0.25
    material.metallic = 0.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    return material

func _spawn_box(
    position: Vector3,
    size: Vector3,
    color: Color,
    has_collision: bool = true,
    material_override: Material = null
) -> void:
    var node := StaticBody3D.new()
    node.position = position

    if has_collision:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        node.add_child(collision)

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh

    if material_override:
        mesh_instance.material_override = material_override
    else:
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 0.95
        material.metallic = 0.0
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        mesh_instance.material_override = material

    node.add_child(mesh_instance)
    geometry_root.add_child(node)
