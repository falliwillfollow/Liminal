extends Node3D

signal world_build_progress(progress: float, status: String)
signal world_build_completed
signal beach_transition_requested

const ROAD_LENGTH := 220.0
const ROAD_WIDTH := 8.0
const SIDEWALK_WIDTH := 2.5
const LOT_DEPTH := 22.0
const BLOCK_STEP := 22.0
const HOUSE_COUNT_PER_SIDE := 10
const TERMINUS_Z := ROAD_LENGTH * 0.5 - 10.0
const DOOR_SCRIPT := preload("res://scripts/Door.gd")
const NUMPAD_SCRIPT := preload("res://scripts/Numpad.gd")
const NUMPAD_BUTTON_SCRIPT := preload("res://scripts/NumpadButton.gd")
const BLACK_CUBE_SCRIPT := preload("res://scripts/BlackCube.gd")
const BANANA_MODEL_PATH := "res://assets/models/banana/banana.glb"
const FLOWERS_MODEL_PATH := "res://assets/models/flowers/flowers.glb"
const DEAD_TREE_MODEL_PATH := "res://assets/models/dead_tree/65539ff7-ff6b-4036-ad02-8233b6ce748f.glb"
const REVIEW_TABLE_POS := Vector3(6.8, 0.0, 111.0)
const ASYLUM_EXTERIOR_DIFFUSE_PATH := "res://assets/textures/asylum/interior_concrete_wall_001_diff_1k.jpg"
const ASYLUM_EXTERIOR_NORMAL_PATH := "res://assets/textures/asylum/interior_concrete_wall_001_nor_gl_1k.jpg"
const ASYLUM_EXTERIOR_ROUGHNESS_PATH := "res://assets/textures/asylum/interior_concrete_wall_001_rough_1k.jpg"
const ASYLUM_INTERIOR_DIFFUSE_PATH := "res://assets/textures/asylum/interior_concrete_wall_001_diff_1k.jpg"
const ASYLUM_INTERIOR_NORMAL_PATH := "res://assets/textures/asylum/interior_concrete_wall_001_nor_gl_1k.jpg"
const ASYLUM_INTERIOR_ROUGHNESS_PATH := "res://assets/textures/asylum/interior_concrete_wall_001_rough_1k.jpg"
const ASYLUM_FLOOR_DIFFUSE_PATH := "res://assets/textures/asylum/floor_long_white_tiles_diff_1k.jpg"
const ASYLUM_FLOOR_NORMAL_PATH := "res://assets/textures/asylum/floor_long_white_tiles_nor_gl_1k.jpg"
const ASYLUM_FLOOR_ROUGHNESS_PATH := "res://assets/textures/asylum/floor_long_white_tiles_rough_1k.jpg"
const ASYLUM_TEXTURE_WORLD_SCALE := 0.22
const SPACE1_TEXTURE_PATH := "res://assets/textures/space/space1.jpg"
const SPACE2_TEXTURE_PATH := "res://assets/textures/space/space2.jpg"
const SPACE3_TEXTURE_PATH := "res://assets/textures/space/space3.jpg"
const SPACE4_TEXTURE_PATH := "res://assets/textures/space/space4.jpg"
const FOUNTAIN_WATER_AUDIO_PATH := "res://assets/sounds/fountain/water_loop.wav"

@onready var geometry_root: Node3D = $GeometryRoot

var _rng := RandomNumberGenerator.new()
var _water_stream_droplets: Array[Dictionary] = []
var _space_house_chaos_cubes: Array[Dictionary] = []
var _asylum_exterior_material: StandardMaterial3D
var _asylum_interior_material: StandardMaterial3D
var _asylum_floor_material: StandardMaterial3D
var _asylum_window_material: StandardMaterial3D
var _space_panel_materials: Dictionary = {}
var _space4_house_material: StandardMaterial3D
var _flowers_scene: PackedScene
var _dead_tree_scene: PackedScene
var _space4_room_spawn_position := Vector3.ZERO
var _space4_room_look_target := Vector3.ZERO
var _space4_room_cube_target := Vector3.ZERO
var _space4_room_spawn_ready := false
var _world_ready := false
var _space_house_hole_enabled := false
var _space_house_hole_x_min := 0.0
var _space_house_hole_x_max := 0.0
var _space_house_hole_z_min := 0.0
var _space_house_hole_z_max := 0.0

func _ready() -> void:
    _rng.seed = 24031998
    _flowers_scene = _load_packed_scene(FLOWERS_MODEL_PATH)
    _dead_tree_scene = _load_packed_scene(DEAD_TREE_MODEL_PATH)
    _setup_asylum_materials()
    _emit_world_build_progress(0.01, "Preparing world")
    call_deferred("_build_world_async")

func _process(delta: float) -> void:
    if _water_stream_droplets.is_empty() and _space_house_chaos_cubes.is_empty():
        return

    if not _water_stream_droplets.is_empty():
        for i in range(_water_stream_droplets.size()):
            var droplet_data: Dictionary = _water_stream_droplets[i]
            var droplet_node: MeshInstance3D = droplet_data["node"]
            var t: float = float(droplet_data["t"]) + delta * float(droplet_data["speed"])
            if t >= 1.0:
                t -= floorf(t)
            droplet_data["t"] = t
            _water_stream_droplets[i] = droplet_data

            var start: Vector3 = droplet_data["start"]
            var control: Vector3 = droplet_data["control"]
            var end: Vector3 = droplet_data["end"]
            var point := _quadratic_bezier(start, control, end, t)
            droplet_node.position = point

    if not _space_house_chaos_cubes.is_empty():
        for i in range(_space_house_chaos_cubes.size()):
            var cube_data: Dictionary = _space_house_chaos_cubes[i]
            var cube_node: Node3D = cube_data["node"]
            var t_cube: float = float(cube_data["time"]) + delta
            cube_data["time"] = t_cube

            var base_spin: Vector3 = cube_data["base_spin"]
            var wobble: Vector3 = cube_data["wobble"]
            var phase: Vector3 = cube_data["phase"]
            var spin := Vector3(
                base_spin.x + sin(t_cube * 1.13 + phase.x) * wobble.x,
                base_spin.y + sin(t_cube * 0.91 + phase.y) * wobble.y,
                base_spin.z + cos(t_cube * 1.37 + phase.z) * wobble.z
            )
            cube_node.rotate_x(deg_to_rad(spin.x * delta))
            cube_node.rotate_y(deg_to_rad(spin.y * delta))
            cube_node.rotate_z(deg_to_rad(spin.z * delta))

            if bool(cube_data.get("descent_active", false)):
                var duration := maxf(float(cube_data.get("descent_duration", 12.0)), 0.01)
                var t_desc := minf(float(cube_data.get("descent_t", 0.0)) + delta / duration, 1.0)
                cube_data["descent_t"] = t_desc
                var start_pos: Vector3 = cube_data["descent_start"]
                var mid_pos: Vector3 = cube_data["descent_mid"]
                var end_pos: Vector3 = cube_data["descent_end"]
                var split := clampf(float(cube_data.get("descent_split", 0.58)), 0.1, 0.9)
                if t_desc <= split:
                    var t_horizontal := t_desc / split
                    cube_node.position = start_pos.lerp(mid_pos, t_horizontal)
                else:
                    var t_vertical := (t_desc - split) / (1.0 - split)
                    cube_node.position = mid_pos.lerp(end_pos, t_vertical)
                if t_desc >= 1.0:
                    cube_data["descent_active"] = false
                    cube_data["descent_done"] = true

            _space_house_chaos_cubes[i] = cube_data

func _build_world_async() -> void:
    await get_tree().process_frame

    _spawn_road()
    _emit_world_build_progress(0.08, "Building roads")
    await get_tree().process_frame

    _spawn_sidewalks()
    _emit_world_build_progress(0.14, "Placing sidewalks")
    await get_tree().process_frame

    await _spawn_houses_async()

    _spawn_ground()
    _emit_world_build_progress(0.74, "Generating terrain")
    await get_tree().process_frame

    _spawn_terminus_and_institution()
    _emit_world_build_progress(0.9, "Constructing asylum")
    await get_tree().process_frame

    _spawn_asset_review_table()
    _add_street_lights()
    _emit_world_build_progress(1.0, "Ready")

    _world_ready = true
    world_build_completed.emit()

func _build_town() -> void:
    _spawn_road()
    _spawn_sidewalks()
    _spawn_houses()
    _spawn_ground()
    _spawn_terminus_and_institution()
    _spawn_asset_review_table()
    _add_street_lights()

func _spawn_houses_async() -> void:
    var first_z := -((HOUSE_COUNT_PER_SIDE - 1) * BLOCK_STEP) * 0.5
    var left_lot_x := -(ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH + LOT_DEPTH * 0.5)
    var right_lot_x := (ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH + LOT_DEPTH * 0.5)

    for i in range(HOUSE_COUNT_PER_SIDE):
        var z := first_z + (i * BLOCK_STEP)
        var left_is_space4_house := i == (HOUSE_COUNT_PER_SIDE - 4)
        _spawn_lot(left_lot_x, z, true, left_is_space4_house)
        _spawn_lot(right_lot_x, z, false)

        var row_progress := float(i + 1) / float(HOUSE_COUNT_PER_SIDE)
        _emit_world_build_progress(
            0.2 + row_progress * 0.52,
            "Placing houses %d/%d" % [i + 1, HOUSE_COUNT_PER_SIDE]
        )
        await get_tree().process_frame

func _spawn_ground() -> void:
    var ground_color := Color(0.17, 0.2, 0.16)
    if _space_house_hole_enabled:
        _spawn_floor_with_rect_hole(
            0.0,
            -0.55,
            0.0,
            220.0,
            1.1,
            ROAD_LENGTH + 30.0,
            _space_house_hole_x_min,
            _space_house_hole_x_max,
            _space_house_hole_z_min,
            _space_house_hole_z_max,
            ground_color
        )
        return
    _spawn_box(Vector3(0, -0.55, 0), Vector3(220, 1.1, ROAD_LENGTH + 30.0), ground_color)

func _spawn_road() -> void:
    var road_end_z := TERMINUS_Z - 7.0
    var road_length := road_end_z + (ROAD_LENGTH * 0.5)
    var road_center_z := -ROAD_LENGTH * 0.5 + (road_length * 0.5)
    _spawn_box(Vector3(0, 0.02, road_center_z), Vector3(ROAD_WIDTH, 0.04, road_length), Color(0.1, 0.1, 0.11), false)

    # Dashed center line
    var dash_count := int(road_length / 7.0)
    for i in range(dash_count):
        var z := -ROAD_LENGTH * 0.5 + 4.0 + (i * 7.0)
        _spawn_box(Vector3(0, 0.04, z), Vector3(0.2, 0.03, 2.8), Color(0.75, 0.72, 0.58), false)

func _spawn_sidewalks() -> void:
    var walk_end_z := TERMINUS_Z - 9.0
    var walk_length := walk_end_z + (ROAD_LENGTH * 0.5)
    var walk_center_z := -ROAD_LENGTH * 0.5 + (walk_length * 0.5)
    var left_x := -(ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5)
    var right_x := (ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5)
    _spawn_box(Vector3(left_x, 0.04, walk_center_z), Vector3(SIDEWALK_WIDTH, 0.08, walk_length), Color(0.46, 0.45, 0.41))
    _spawn_box(Vector3(right_x, 0.04, walk_center_z), Vector3(SIDEWALK_WIDTH, 0.08, walk_length), Color(0.46, 0.45, 0.41))

func _spawn_houses() -> void:
    var first_z := -((HOUSE_COUNT_PER_SIDE - 1) * BLOCK_STEP) * 0.5
    var left_lot_x := -(ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH + LOT_DEPTH * 0.5)
    var right_lot_x := (ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH + LOT_DEPTH * 0.5)

    for i in range(HOUSE_COUNT_PER_SIDE):
        var z := first_z + (i * BLOCK_STEP)
        var left_is_space4_house := i == (HOUSE_COUNT_PER_SIDE - 4)
        _spawn_lot(left_lot_x, z, true, left_is_space4_house)
        _spawn_lot(right_lot_x, z, false)

func _emit_world_build_progress(progress: float, status: String) -> void:
    world_build_progress.emit(clampf(progress, 0.0, 1.0), status)

func _spawn_lot(lot_center_x: float, lot_center_z: float, face_right: bool, force_space4_wrap: bool = false) -> void:
    var grass_color := Color(
        _rng.randf_range(0.18, 0.24),
        _rng.randf_range(0.38, 0.5),
        _rng.randf_range(0.18, 0.25)
    )

    var toward_road := 1.0 if face_right else -1.0
    var house_x := lot_center_x + (toward_road * _rng.randf_range(0.4, 2.2))
    var house_z := lot_center_z + _rng.randf_range(-2.4, 2.4)
    var lot_hole_data := {}

    var base_color := Color(
        _rng.randf_range(0.38, 0.66),
        _rng.randf_range(0.37, 0.63),
        _rng.randf_range(0.33, 0.58)
    )
    var trim_color := base_color.lightened(0.16)
    var roof_color := base_color.darkened(0.36)

    if force_space4_wrap and _space4_house_material:
        lot_hole_data = _spawn_space4_house(Vector3(house_x, 0.0, house_z), toward_road)
        _spawn_lot_surface(lot_center_x, lot_center_z, grass_color, lot_hole_data)
    else:
        _spawn_lot_surface(lot_center_x, lot_center_z, grass_color)
        if _rng.randf() < 0.52:
            _spawn_ranch_house(Vector3(house_x, 0.0, house_z), toward_road, base_color, trim_color, roof_color)
        else:
            _spawn_colonial_house(Vector3(house_x, 0.0, house_z), toward_road, base_color, trim_color, roof_color)

    # Driveway toward the road (wider for larger homes)
    var drive_start_x := lot_center_x + (toward_road * (LOT_DEPTH * 0.15))
    var drive_size_x := LOT_DEPTH * 0.72
    _spawn_box(
        Vector3(drive_start_x, 0.035, lot_center_z - (BLOCK_STEP * 0.19)),
        Vector3(drive_size_x, 0.05, 2.2),
        Color(0.14, 0.14, 0.15),
        false
    )

    _spawn_lot_flowers(lot_center_x, lot_center_z, house_x, house_z, toward_road, lot_hole_data)

func _spawn_lot_surface(lot_center_x: float, lot_center_z: float, grass_color: Color, hole_data: Dictionary = {}) -> void:
    var hole_enabled: bool = bool(hole_data.get("enabled", false))
    if hole_enabled:
        _spawn_floor_with_rect_hole(
            lot_center_x,
            0.03,
            lot_center_z,
            LOT_DEPTH,
            0.06,
            BLOCK_STEP - 1.5,
            float(hole_data.get("x_min", lot_center_x - 0.1)),
            float(hole_data.get("x_max", lot_center_x + 0.1)),
            float(hole_data.get("z_min", lot_center_z - 0.1)),
            float(hole_data.get("z_max", lot_center_z + 0.1)),
            grass_color,
            null,
            false
        )
        return
    _spawn_box(Vector3(lot_center_x, 0.03, lot_center_z), Vector3(LOT_DEPTH, 0.06, BLOCK_STEP - 1.5), grass_color, false)

func _spawn_lot_flowers(
    lot_center_x: float,
    lot_center_z: float,
    house_x: float,
    house_z: float,
    toward_road: float,
    lot_hole_data: Dictionary = {}
) -> void:
    if not _flowers_scene:
        return

    var lot_w := LOT_DEPTH
    var lot_d := BLOCK_STEP - 1.5
    var driveway_center_x := lot_center_x + (toward_road * (LOT_DEPTH * 0.15))
    var driveway_w := LOT_DEPTH * 0.72
    var driveway_center_z := lot_center_z - (BLOCK_STEP * 0.19)
    var driveway_d := 2.2
    var hole_enabled := bool(lot_hole_data.get("enabled", false))
    var hole_x_min := float(lot_hole_data.get("x_min", 0.0))
    var hole_x_max := float(lot_hole_data.get("x_max", 0.0))
    var hole_z_min := float(lot_hole_data.get("z_min", 0.0))
    var hole_z_max := float(lot_hole_data.get("z_max", 0.0))
    var count := _rng.randi_range(8, 14)
    var attempts := count * 6
    var placed := 0
    var min_spacing := 0.45
    var placed_points: Array[Vector2] = []

    for _i in range(attempts):
        if placed >= count:
            break

        var x := _rng.randf_range(lot_center_x - lot_w * 0.46, lot_center_x + lot_w * 0.46)
        var z := _rng.randf_range(lot_center_z - lot_d * 0.46, lot_center_z + lot_d * 0.46)

        # Keep flowers only on lot grass: not on driveway/front strip, not in
        # the house footprint, and never inside carved lot holes.
        if z < lot_center_z - lot_d * 0.16:
            continue
        if absf(x - driveway_center_x) <= driveway_w * 0.5 and absf(z - driveway_center_z) <= driveway_d * 0.5:
            continue
        if hole_enabled and x >= hole_x_min and x <= hole_x_max and z >= hole_z_min and z <= hole_z_max:
            continue
        if absf(x - house_x) < 3.8 and absf(z - house_z) < 3.4:
            continue

        var candidate := Vector2(x, z)
        var too_close := false
        for p in placed_points:
            if p.distance_to(candidate) < min_spacing:
                too_close = true
                break
        if too_close:
            continue

        var instance := _flowers_scene.instantiate()
        if instance is Node3D:
            var flower := instance as Node3D
            flower.position = Vector3(x, 0.06, z)
            var s := _rng.randf_range(0.32, 0.52)
            flower.scale = Vector3.ONE * s
            flower.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
            geometry_root.add_child(flower)
            placed_points.append(candidate)
            placed += 1

func _spawn_ranch_house(base: Vector3, toward_road: float, body_color: Color, trim_color: Color, roof_color: Color) -> void:
    var main_w := _rng.randf_range(10.0, 13.0)
    var main_h := _rng.randf_range(3.1, 3.8)
    var main_d := _rng.randf_range(8.2, 10.6)
    _spawn_box(base + Vector3(0, main_h * 0.5, 0), Vector3(main_w, main_h, main_d), body_color)

    # Side wing / garage mass
    var wing_w := _rng.randf_range(4.6, 6.8)
    var wing_d := _rng.randf_range(5.2, 7.4)
    var wing_x := base.x - (toward_road * (main_w * 0.42))
    var wing_z := base.z + _rng.randf_range(-1.6, 1.6)
    _spawn_box(Vector3(wing_x, (main_h - 0.3) * 0.5, wing_z), Vector3(wing_w, main_h - 0.3, wing_d), body_color.darkened(0.05))

    # Roof slabs with slight offsets for silhouette variation
    _spawn_box(base + Vector3(0, main_h + 0.25, 0), Vector3(main_w + 0.9, 0.5, main_d + 0.9), roof_color)
    _spawn_box(Vector3(wing_x, main_h + 0.1, wing_z), Vector3(wing_w + 0.7, 0.42, wing_d + 0.7), roof_color.darkened(0.06))

    # Porch and front door facing road
    var porch_x := base.x + (toward_road * (main_w * 0.43))
    _spawn_box(Vector3(porch_x, 0.3, base.z), Vector3(1.6, 0.6, 2.6), trim_color)
    _spawn_box(Vector3(porch_x - (toward_road * 0.32), 1.05, base.z), Vector3(0.12, 1.5, 0.12), trim_color.lightened(0.08))
    _spawn_box(Vector3(porch_x + (toward_road * 0.32), 1.05, base.z), Vector3(0.12, 1.5, 0.12), trim_color.lightened(0.08))
    _spawn_box(Vector3(porch_x + (toward_road * 0.81), 1.05, base.z), Vector3(0.18, 2.1, 0.95), Color(0.2, 0.18, 0.16))

func _spawn_colonial_house(base: Vector3, toward_road: float, body_color: Color, trim_color: Color, roof_color: Color) -> void:
    var main_w := _rng.randf_range(9.0, 12.0)
    var floor_h := _rng.randf_range(2.9, 3.25)
    var main_d := _rng.randf_range(8.0, 10.0)

    # First and second floors
    _spawn_box(base + Vector3(0, floor_h * 0.5, 0), Vector3(main_w, floor_h, main_d), body_color)
    _spawn_box(base + Vector3(0, floor_h * 1.5, 0), Vector3(main_w * 0.9, floor_h, main_d * 0.9), body_color.lightened(0.04))

    # Entry bump-out
    var entry_x := base.x + (toward_road * (main_w * 0.48))
    _spawn_box(Vector3(entry_x, 1.45, base.z), Vector3(1.8, 2.9, 3.0), trim_color)

    # Roof and cap
    _spawn_box(base + Vector3(0, floor_h * 2.05, 0), Vector3(main_w + 0.9, 0.56, main_d + 0.9), roof_color)
    _spawn_box(base + Vector3(0, floor_h * 2.38, 0), Vector3(main_w * 0.38, 0.3, main_d * 0.44), roof_color.darkened(0.08))

    # Front door facing road
    _spawn_box(Vector3(entry_x + (toward_road * 0.94), 1.0, base.z), Vector3(0.18, 2.0, 0.9), Color(0.18, 0.16, 0.15))

    # Small side extension for asymmetry
    var ext_x := base.x - (toward_road * (main_w * 0.43))
    var ext_z := base.z + _rng.randf_range(-1.8, 1.8)
    _spawn_box(Vector3(ext_x, 1.35, ext_z), Vector3(2.6, 2.7, 3.8), body_color.darkened(0.05))

func _spawn_space4_house(base: Vector3, toward_road: float) -> Dictionary:
    var main_w := _rng.randf_range(15.4, 17.2)
    var main_h := _rng.randf_range(6.2, 6.9)
    var main_d := _rng.randf_range(13.8, 15.8)
    var wall_t := 0.28
    var door_w := 1.65
    var door_h := 2.35
    var door_t := 0.12
    var road_wall_x := base.x + toward_road * (main_w * 0.5 - wall_t * 0.5)
    var back_wall_x := base.x - toward_road * (main_w * 0.5 - wall_t * 0.5)
    var side_wall_zn := base.z - (main_d * 0.5 - wall_t * 0.5)
    var side_wall_zp := base.z + (main_d * 0.5 - wall_t * 0.5)
    var side_seg_d := maxf((main_d - door_w) * 0.5, 0.3)
    var side_z_1 := base.z - (door_w * 0.5 + side_seg_d * 0.5)
    var side_z_2 := base.z + (door_w * 0.5 + side_seg_d * 0.5)
    var floor_top_y := 0.08

    var underground_data := _spawn_space4_underground(base, toward_road, floor_top_y, main_w, main_d)
    var stair_hole: Dictionary = underground_data.get("stair_hole", {})
    var stair_hole_x_min := float(stair_hole.get("x_min", base.x - 1.0))
    var stair_hole_x_max := float(stair_hole.get("x_max", base.x + 1.0))
    var stair_hole_z_min := float(stair_hole.get("z_min", base.z - 1.0))
    var stair_hole_z_max := float(stair_hole.get("z_max", base.z + 1.0))

    # Single-level shell with contained stair opening.
    _spawn_floor_with_rect_hole(
        base.x,
        floor_top_y,
        base.z,
        main_w - wall_t * 1.2,
        0.16,
        main_d - wall_t * 1.2,
        stair_hole_x_min,
        stair_hole_x_max,
        stair_hole_z_min,
        stair_hole_z_max,
        Color.WHITE,
        _space4_house_material
    )
    _spawn_box(base + Vector3(0, main_h - 0.12, 0), Vector3(main_w + 0.08, 0.24, main_d + 0.08), Color.WHITE, true, _space4_house_material)
    _spawn_box(Vector3(back_wall_x, main_h * 0.5, base.z), Vector3(wall_t, main_h, main_d), Color.WHITE, true, _space4_house_material)
    _spawn_box(Vector3(base.x, main_h * 0.5, side_wall_zn), Vector3(main_w, main_h, wall_t), Color.WHITE, true, _space4_house_material)
    _spawn_box(Vector3(base.x, main_h * 0.5, side_wall_zp), Vector3(main_w, main_h, wall_t), Color.WHITE, true, _space4_house_material)
    _spawn_box(Vector3(road_wall_x, main_h * 0.5, side_z_1), Vector3(wall_t, main_h, side_seg_d), Color.WHITE, true, _space4_house_material)
    _spawn_box(Vector3(road_wall_x, main_h * 0.5, side_z_2), Vector3(wall_t, main_h, side_seg_d), Color.WHITE, true, _space4_house_material)
    _spawn_box(
        Vector3(road_wall_x, door_h + (main_h - door_h) * 0.5, base.z),
        Vector3(wall_t, main_h - door_h, door_w),
        Color.WHITE,
        true,
        _space4_house_material
    )
    _spawn_box(base + Vector3(0, main_h + 0.16, 0), Vector3(main_w + 0.52, 0.32, main_d + 0.52), Color.WHITE, true, _space4_house_material)

    # Keep global terrain from blocking the descent shaft.
    var terrain_hole: Dictionary = underground_data.get("terrain_hole", {})
    _space_house_hole_enabled = true
    _space_house_hole_x_min = float(terrain_hole.get("x_min", stair_hole_x_min - 0.2))
    _space_house_hole_x_max = float(terrain_hole.get("x_max", stair_hole_x_max + 0.2))
    _space_house_hole_z_min = float(terrain_hole.get("z_min", stair_hole_z_min - 0.2))
    _space_house_hole_z_max = float(terrain_hole.get("z_max", stair_hole_z_max + 0.2))

    var hinge_margin := 0.03
    var door_x := road_wall_x - toward_road * 0.01
    var door_hinge_z := base.z + door_w * 0.5 - hinge_margin
    var locked_door := _spawn_interactable_door(
        Vector3(door_x, door_h * 0.5, door_hinge_z),
        Vector3(door_w, door_h, door_t),
        Color(0.08, 0.08, 0.09),
        toward_road,
        -(door_w * 0.5 - hinge_margin),
        -90.0 * toward_road,
        true,
        _make_jet_black_unlit_material()
    )

    var chaos_cube := _spawn_space_house_chaos_cube(base, main_h)
    var keypad := _spawn_space4_house_numpad(base, main_w, main_h, main_d, toward_road)
    if keypad and locked_door:
        if keypad.has_method("register_unlock_target"):
            keypad.register_unlock_target(locked_door)
        keypad.set("unlock_target_paths", [keypad.get_path_to(locked_door)])
        keypad.set("required_code", "143")
    if keypad and chaos_cube and keypad.has_signal("code_accepted"):
        var callback := Callable(self, "_on_space4_keypad_code_accepted").bind(chaos_cube)
        if not keypad.is_connected("code_accepted", callback):
            keypad.connect("code_accepted", callback)

    return underground_data.get("lot_hole", {"enabled": false})

func _spawn_space_house_chaos_cube(base: Vector3, main_h: float) -> Node3D:
    var cube_root := StaticBody3D.new()
    cube_root.position = base + Vector3(0.0, main_h + 5.4, 0.0)
    cube_root.set_script(BLACK_CUBE_SCRIPT)

    var cube_collision := CollisionShape3D.new()
    var cube_shape := BoxShape3D.new()
    cube_shape.size = Vector3(1.7, 1.7, 1.7)
    cube_collision.shape = cube_shape
    cube_root.add_child(cube_collision)

    var cube_mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = Vector3(1.35, 1.35, 1.35)
    cube_mesh.mesh = cube

    cube_mesh.material_override = _make_jet_black_unlit_material()

    cube_root.add_child(cube_mesh)
    geometry_root.add_child(cube_root)
    if cube_root.has_signal("activated"):
        var callback := Callable(self, "_on_space_house_cube_activated")
        if not cube_root.is_connected("activated", callback):
            cube_root.connect("activated", callback)

    _space_house_chaos_cubes.append({
        "node": cube_root,
        "time": _rng.randf_range(0.0, TAU),
        "base_spin": Vector3(
            _rng.randf_range(22.0, 36.0),
            _rng.randf_range(27.0, 43.0),
            _rng.randf_range(24.0, 38.0)
        ),
        "wobble": Vector3(
            _rng.randf_range(12.0, 21.0),
            _rng.randf_range(10.0, 20.0),
            _rng.randf_range(13.0, 22.0)
        ),
        "phase": Vector3(
            _rng.randf_range(0.0, TAU),
            _rng.randf_range(0.0, TAU),
            _rng.randf_range(0.0, TAU)
        ),
        "descent_active": false,
        "descent_done": false,
        "descent_t": 0.0,
        "descent_duration": 12.0
    })
    return cube_root

func _on_space4_keypad_code_accepted(_numpad: Numpad, cube_root: Node3D) -> void:
    _start_space_house_cube_descent(cube_root)

func _on_space_house_cube_activated(_cube_root: Node3D) -> void:
    beach_transition_requested.emit()

func _start_space_house_cube_descent(cube_root: Node3D) -> void:
    if cube_root == null:
        return
    if not _space4_room_spawn_ready:
        return

    var start_pos := cube_root.position
    var end_pos := _space4_room_cube_target
    var mid_pos := Vector3(end_pos.x, start_pos.y, end_pos.z)

    for i in range(_space_house_chaos_cubes.size()):
        var cube_data: Dictionary = _space_house_chaos_cubes[i]
        if cube_data.get("node") != cube_root:
            continue
        if bool(cube_data.get("descent_done", false)) or bool(cube_data.get("descent_active", false)):
            return

        cube_data["descent_active"] = true
        cube_data["descent_t"] = 0.0
        cube_data["descent_duration"] = 14.0
        cube_data["descent_split"] = 0.62
        cube_data["descent_start"] = start_pos
        cube_data["descent_mid"] = mid_pos
        cube_data["descent_end"] = end_pos
        _space_house_chaos_cubes[i] = cube_data
        return

func _spawn_space4_underground(
    base: Vector3,
    toward_road: float,
    floor_top_y: float,
    main_w: float,
    main_d: float
) -> Dictionary:
    var stair_w := 2.3
    var stair_run := 15.5
    var stair_drop := 13.0
    var stair_steps := 62
    var stair_tread := stair_run / float(stair_steps)
    var stair_riser := stair_drop / float(stair_steps)
    var run_dir := -toward_road
    var stair_start_x := base.x - toward_road * (main_w * 0.18)
    var stair_z := base.z + main_d * 0.2
    var stair_end_x := stair_start_x + run_dir * stair_run

    var stair_hole_x_min := minf(stair_start_x, stair_end_x) - 0.22
    var stair_hole_x_max := maxf(stair_start_x, stair_end_x) + 0.22
    var stair_hole_z_min := stair_z - stair_w * 0.5 - 0.06
    var stair_hole_z_max := stair_z + stair_w * 0.5 + 0.06
    # Keep the floor opening tight to the stair entry: enough headroom to ascend,
    # but no large pre-stair pit inside the room.
    var top_open_before := 0.18
    var top_open_along := 4.0
    var floor_hole_x_min := stair_start_x
    var floor_hole_x_max := stair_start_x
    if run_dir < 0.0:
        floor_hole_x_min = stair_start_x - top_open_along
        floor_hole_x_max = stair_start_x + top_open_before
    else:
        floor_hole_x_min = stair_start_x - top_open_before
        floor_hole_x_max = stair_start_x + top_open_along
    var house_floor_surface_y := floor_top_y + 0.08

    var stair_wall_mat := _make_torch_lit_material(Color(0.06, 0.06, 0.06))

    for i in range(stair_steps):
        var y := house_floor_surface_y - (stair_riser * 0.5 + float(i) * stair_riser)
        var x := stair_start_x + run_dir * (float(i) * stair_tread + stair_tread * 0.5)
        _spawn_box(
            Vector3(x, y, stair_z),
            Vector3(stair_tread + 0.02, stair_riser, stair_w),
            Color(0.08, 0.08, 0.08),
            false,
            stair_wall_mat
        )
    var stair_pitch := rad_to_deg(atan(stair_drop / stair_run))
    var stair_ramp_t := 0.36
    var stair_slope_len := sqrt(stair_run * stair_run + stair_drop * stair_drop)
    var stair_ramp_mid_y := house_floor_surface_y - stair_drop * 0.5 - cos(deg_to_rad(stair_pitch)) * stair_ramp_t * 0.5 - 0.01
    var stair_bottom_y := house_floor_surface_y - stair_drop - 0.16
    _spawn_ramp(
        Vector3((stair_start_x + stair_end_x) * 0.5, stair_ramp_mid_y, stair_z),
        Vector3(stair_slope_len + 0.28, stair_ramp_t, stair_w + 0.16),
        0.0,
        Color(0, 0, 0),
        false,
        true,
        0.0,
        -run_dir * stair_pitch
    )
    _spawn_box(
        Vector3(stair_end_x - run_dir * 0.35, stair_bottom_y + 0.07, stair_z),
        Vector3(0.95, 0.14, stair_w + 0.16),
        Color(0, 0, 0),
        true,
        stair_wall_mat
    )

    var shaft_h := stair_drop + 0.6
    var shaft_y := house_floor_surface_y - shaft_h * 0.5
    var shaft_wall_t := 0.2
    var shaft_len := (stair_hole_x_max - stair_hole_x_min) + 0.04
    var shaft_center_x := (stair_hole_x_min + stair_hole_x_max) * 0.5
    var shaft_outer_z_min := stair_hole_z_min - shaft_wall_t * 0.5
    var shaft_outer_z_max := stair_hole_z_max + shaft_wall_t * 0.5
    _spawn_box(
        Vector3(shaft_center_x, shaft_y, shaft_outer_z_min),
        Vector3(shaft_len, shaft_h, shaft_wall_t),
        Color(0.02, 0.02, 0.02),
        true,
        stair_wall_mat
    )
    _spawn_box(
        Vector3(shaft_center_x, shaft_y, shaft_outer_z_max),
        Vector3(shaft_len, shaft_h, shaft_wall_t),
        Color(0.02, 0.02, 0.02),
        true,
        stair_wall_mat
    )

    # Giant chamber fully underground with a wide portal from the stairs.
    var room_floor_y := house_floor_surface_y - stair_drop - 0.16
    var room_h := 10.8
    var room_w := 72.0
    var room_d := 64.0
    var wall_t_room := 0.46
    var room_center_x := stair_end_x + run_dir * (room_w * 0.5 + 2.4)
    var room_center_z := stair_z
    var room_mid_y := room_floor_y + room_h * 0.5
    var near_wall_x := room_center_x - run_dir * (room_w * 0.5 - wall_t_room * 0.5)
    var far_wall_x := room_center_x + run_dir * (room_w * 0.5 - wall_t_room * 0.5)
    _space4_room_spawn_position = Vector3(room_center_x - run_dir * (room_w * 0.33), room_floor_y + 0.2, room_center_z)
    _space4_room_look_target = Vector3(room_center_x, room_floor_y + 1.6, room_center_z)
    _space4_room_cube_target = Vector3(room_center_x, room_floor_y + 1.25, room_center_z)
    _space4_room_spawn_ready = true

    var black_room_mat := _make_torch_lit_material(Color(0.025, 0.025, 0.025))

    _spawn_box(
        Vector3(room_center_x, room_floor_y, room_center_z),
        Vector3(room_w, 0.24, room_d),
        Color.BLACK,
        true,
        black_room_mat
    )
    _spawn_box(
        Vector3(room_center_x, room_floor_y + room_h - 0.14, room_center_z),
        Vector3(room_w, 0.28, room_d),
        Color.BLACK,
        true,
        black_room_mat
    )

    var portal_w := stair_w + 0.7
    var portal_seg_d := maxf((room_d - portal_w) * 0.5, 0.25)
    _spawn_box(
        Vector3(near_wall_x, room_mid_y, room_center_z - (portal_w * 0.5 + portal_seg_d * 0.5)),
        Vector3(wall_t_room, room_h, portal_seg_d),
        Color.BLACK,
        true,
        black_room_mat
    )
    _spawn_box(
        Vector3(near_wall_x, room_mid_y, room_center_z + (portal_w * 0.5 + portal_seg_d * 0.5)),
        Vector3(wall_t_room, room_h, portal_seg_d),
        Color.BLACK,
        true,
        black_room_mat
    )
    # Keep this portal full-height so the stairwell cannot be blocked mid-descent.

    _spawn_box(
        Vector3(far_wall_x, room_mid_y, room_center_z),
        Vector3(wall_t_room, room_h, room_d),
        Color.BLACK,
        true,
        black_room_mat
    )
    _spawn_box(
        Vector3(room_center_x, room_mid_y, room_center_z - room_d * 0.5 + wall_t_room * 0.5),
        Vector3(room_w, room_h, wall_t_room),
        Color.BLACK,
        true,
        black_room_mat
    )
    _spawn_box(
        Vector3(room_center_x, room_mid_y, room_center_z + room_d * 0.5 - wall_t_room * 0.5),
        Vector3(room_w, room_h, wall_t_room),
        Color.BLACK,
        true,
        black_room_mat
    )
    _spawn_underground_room_fill_lights(Vector3(room_center_x, room_floor_y, room_center_z), room_w, room_d, room_h)
    _spawn_underground_dead_trees(
        Vector3(room_center_x, room_floor_y + 0.12, room_center_z),
        room_w,
        room_d,
        room_h,
        _space4_room_spawn_position
    )

    var landing_len := absf(near_wall_x - stair_end_x) + 0.9
    var landing_center_x := (near_wall_x + stair_end_x) * 0.5
    _spawn_box(
        Vector3(landing_center_x, room_floor_y + 0.12, stair_z),
        Vector3(landing_len, 0.24, portal_w),
        Color.BLACK,
        true,
        black_room_mat
    )
    var connector_top_y := house_floor_surface_y
    var connector_wall_h := maxf(connector_top_y - room_floor_y, 0.2)
    var connector_wall_y := room_floor_y + connector_wall_h * 0.5
    var connector_wall_t := 0.2
    _spawn_box(
        Vector3(landing_center_x, connector_wall_y, shaft_outer_z_min),
        Vector3(landing_len, connector_wall_h, connector_wall_t),
        Color.BLACK,
        true,
        black_room_mat
    )
    _spawn_box(
        Vector3(landing_center_x, connector_wall_y, shaft_outer_z_max),
        Vector3(landing_len, connector_wall_h, connector_wall_t),
        Color.BLACK,
        true,
        black_room_mat
    )

    # Torches down the shaft and around the giant chamber.
    for i in range(8):
        var t := float(i + 1) / 9.0
        var tx := stair_start_x + run_dir * (stair_run * t)
        var ty := house_floor_surface_y + 0.92 - stair_drop * t
        _spawn_wall_torch(Vector3(tx, ty, stair_z - stair_w * 0.5 - 0.12), -90.0)
        _spawn_wall_torch(Vector3(tx, ty, stair_z + stair_w * 0.5 + 0.12), 90.0)

    for i in range(8):
        var t_room := float(i + 1) / 9.0
        var torch_z := lerpf(room_center_z - room_d * 0.38, room_center_z + room_d * 0.38, t_room)
        _spawn_wall_torch(
            Vector3(room_center_x - room_w * 0.5 + wall_t_room + 0.08, room_floor_y + 1.7, torch_z),
            90.0
        )
        _spawn_wall_torch(
            Vector3(room_center_x + room_w * 0.5 - wall_t_room - 0.08, room_floor_y + 1.7, torch_z),
            -90.0
        )

    return {
        "stair_hole": {
            "x_min": floor_hole_x_min,
            "x_max": floor_hole_x_max,
            "z_min": stair_hole_z_min,
            "z_max": stair_hole_z_max
        },
        "lot_hole": {
            "enabled": true,
            "x_min": stair_hole_x_min - 0.04,
            "x_max": stair_hole_x_max + 0.04,
            "z_min": stair_hole_z_min - 0.04,
            "z_max": stair_hole_z_max + 0.04
        },
        "terrain_hole": {
            "x_min": stair_hole_x_min - 0.08,
            "x_max": stair_hole_x_max + 0.08,
            "z_min": stair_hole_z_min - 0.08,
            "z_max": stair_hole_z_max + 0.08
        }
    }

func get_space4_room_spawn_data() -> Dictionary:
    return {
        "ready": _space4_room_spawn_ready,
        "position": _space4_room_spawn_position,
        "look_target": _space4_room_look_target
    }

func _spawn_space4_house_numpad(base: Vector3, main_w: float, _main_h: float, _main_d: float, toward_road: float) -> Node3D:
    var panel_scale := 0.15 # 85% smaller
    var road_wall_x := base.x + toward_road * (main_w * 0.5 + 0.06)
    var door_right_offset_z := -toward_road * 1.25
    var panel_pos := Vector3(road_wall_x, 1.35, base.z + door_right_offset_z)
    var panel_yaw := -90.0 * toward_road

    var keypad := StaticBody3D.new()
    keypad.position = panel_pos
    keypad.rotation_degrees.y = panel_yaw
    keypad.scale = Vector3.ONE * panel_scale
    keypad.set_script(NUMPAD_SCRIPT)
    keypad.set("required_code", "143")

    var body_shape := CollisionShape3D.new()
    var body_box := BoxShape3D.new()
    body_box.size = Vector3(1.35, 1.8, 0.1)
    body_shape.shape = body_box
    keypad.add_child(body_shape)

    var body_mesh := MeshInstance3D.new()
    body_mesh.name = "BodyMesh"
    var body_box_mesh := BoxMesh.new()
    body_box_mesh.size = Vector3(1.35, 1.8, 0.08)
    body_mesh.mesh = body_box_mesh
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.12, 0.12, 0.13)
    body_mat.roughness = 0.6
    body_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    body_mesh.material_override = body_mat
    keypad.add_child(body_mesh)

    var led_mesh := MeshInstance3D.new()
    led_mesh.name = "DisplayMesh"
    led_mesh.position = Vector3(0.0, 0.64, -0.06)
    var led_box := BoxMesh.new()
    led_box.size = Vector3(1.08, 0.28, 0.03)
    led_mesh.mesh = led_box
    var led_mat := StandardMaterial3D.new()
    led_mat.albedo_color = Color(0.06, 0.12, 0.06)
    led_mat.emission_enabled = true
    led_mat.emission = Color(0.12, 0.24, 0.12)
    led_mat.roughness = 0.4
    led_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    led_mesh.material_override = led_mat
    keypad.add_child(led_mesh)

    var led_label := Label3D.new()
    led_label.name = "DisplayLabel"
    led_label.text = "-"
    led_label.position = Vector3(0.0, 0.64, -0.078)
    led_label.pixel_size = 0.0078
    led_label.rotation_degrees.y = 180.0
    led_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    led_label.modulate = Color(0.72, 1.0, 0.7)
    led_label.outline_size = 2
    led_label.no_depth_test = false
    keypad.add_child(led_label)

    var focus_point := Marker3D.new()
    focus_point.name = "FocusPoint"
    focus_point.position = Vector3(0.0, 0.38, -0.12)
    keypad.add_child(focus_point)

    var keys: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "E"]
    var row_count := 4
    var col_count := 3
    var key_w := 0.28
    var key_h := 0.2
    var key_d := 0.08
    var start_x := -0.38
    var start_y := 0.29
    var x_step := 0.38
    var y_step := -0.34

    for idx in range(keys.size()):
        var row := int(idx / col_count)
        var col := int(idx % col_count)
        var visual_col := (col_count - 1) - col
        var key_body := StaticBody3D.new()
        key_body.position = Vector3(start_x + visual_col * x_step, start_y + row * y_step, -0.09)
        key_body.set_script(NUMPAD_BUTTON_SCRIPT)
        key_body.set("key_value", keys[idx])
        key_body.set("numpad_path", NodePath(".."))

        var key_collision := CollisionShape3D.new()
        var key_shape := BoxShape3D.new()
        key_shape.size = Vector3(key_w, key_h, key_d)
        key_collision.shape = key_shape
        key_body.add_child(key_collision)

        var key_mesh := MeshInstance3D.new()
        var key_box := BoxMesh.new()
        key_box.size = Vector3(key_w, key_h, key_d * 0.7)
        key_mesh.mesh = key_box
        var key_mat := StandardMaterial3D.new()
        key_mat.albedo_color = Color(0.84, 0.84, 0.84)
        key_mat.roughness = 0.7
        key_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        key_mesh.material_override = key_mat
        key_body.add_child(key_mesh)

        var key_label := Label3D.new()
        key_label.text = keys[idx]
        key_label.position = Vector3(0.0, 0.0, -0.038)
        key_label.pixel_size = 0.0068
        key_label.rotation_degrees.y = 180.0
        key_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
        key_label.modulate = Color(0.1, 0.1, 0.1)
        key_body.add_child(key_label)

        keypad.add_child(key_body)

    geometry_root.add_child(keypad)
    return keypad

func _add_street_lights() -> void:
    var spacing := 24.0
    var light_span := (TERMINUS_Z - 12.0) + (ROAD_LENGTH * 0.5)
    var count := int(light_span / spacing)
    var x := ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH + 1.3

    for i in range(count):
        var z := -ROAD_LENGTH * 0.5 + 8.0 + (i * spacing)
        _spawn_street_light(Vector3(x, 0, z))
        _spawn_street_light(Vector3(-x, 0, z))

func _spawn_terminus_and_institution() -> void:
    var terminus_radius := 16.0
    var curb_thickness := 1.2

    # Circular turnaround pad
    _spawn_cylinder(Vector3(0, 0.025, TERMINUS_Z), terminus_radius, 0.05, Color(0.1, 0.1, 0.11), false)
    _spawn_cylinder(Vector3(0, 0.065, TERMINUS_Z), terminus_radius + curb_thickness, 0.08, Color(0.5, 0.48, 0.42), true)
    _spawn_cylinder(Vector3(0, 0.075, TERMINUS_Z), terminus_radius - 5.2, 0.08, Color(0.16, 0.19, 0.15), false)

    # Central island feature: detailed fountain.
    _spawn_fountain(Vector3(0, 0, TERMINUS_Z))

    # Institution sits beyond the terminus
    var front_z := TERMINUS_Z + terminus_radius + 5.0
    _spawn_asylum(front_z)

func _spawn_fountain(center: Vector3) -> void:
    var stone := Color(0.54, 0.53, 0.5)
    var stone_dark := Color(0.34, 0.34, 0.33)
    var stone_light := Color(0.64, 0.62, 0.58)
    var water := Color(0.22, 0.47, 0.7)

    # Plinth and bowl basin. Use ring walls (not full disks) so the center is visually open.
    _spawn_cylinder(center + Vector3(0, 0.18, 0), 4.95, 0.36, stone_dark)
    _spawn_cylinder(center + Vector3(0, 0.35, 0), 4.5, 0.08, stone)
    _spawn_ring_wall(center + Vector3(0, 0.54, 0), 3.36, 0.24, 0.34, 24, stone)
    _spawn_ring_wall(center + Vector3(0, 0.74, 0), 3.68, 0.22, 0.32, 26, stone)
    _spawn_ring_wall(center + Vector3(0, 0.92, 0), 3.98, 0.18, 0.34, 28, stone_light)
    _spawn_ring_wall(center + Vector3(0, 0.96, 0), 3.76, 0.08, 0.2, 24, stone_light, false)

    # Bowl interior floor and water surface (lower than rim so depth is readable).
    _spawn_cylinder(center + Vector3(0, 0.4, 0), 2.9, 0.08, stone_dark, false)
    _spawn_cylinder(center + Vector3(0, 0.52, 0), 3.12, 0.06, Color(0.27, 0.56, 0.78), false)

    # Center pedestal and top bowl
    _spawn_cylinder(center + Vector3(0, 1.12, 0), 0.95, 1.24, stone)
    _spawn_cylinder(center + Vector3(0, 1.86, 0), 1.2, 0.16, stone_light)
    _spawn_cylinder(center + Vector3(0, 2.1, 0), 0.55, 0.32, stone_dark)
    _spawn_cylinder(center + Vector3(0, 2.26, 0), 0.78, 0.1, stone_light)
    _spawn_cylinder(center + Vector3(0, 2.31, 0), 0.62, 0.08, water, false)

    # Decorative ring posts around the pedestal
    var post_count := 8
    for i in range(post_count):
        var angle := TAU * float(i) / float(post_count)
        var px := cos(angle) * 1.55
        var pz := sin(angle) * 1.55
        _spawn_box(center + Vector3(px, 1.55, pz), Vector3(0.14, 0.66, 0.14), stone_light)

    # Four ornate spouts and visible water streams into the basin
    var spout_dirs: Array[Vector3] = [
        Vector3(1, 0, 0),
        Vector3(-1, 0, 0),
        Vector3(0, 0, 1),
        Vector3(0, 0, -1)
    ]
    for dir in spout_dirs:
        var spout_center := center + Vector3(dir.x * 1.24, 2.02, dir.z * 1.24)
        var spout_size := Vector3(0.58, 0.14, 0.2) if absf(dir.x) > 0.5 else Vector3(0.2, 0.14, 0.58)
        _spawn_box(spout_center, spout_size, stone_light)

        var nozzle_center := spout_center + Vector3(dir.x * 0.36, -0.04, dir.z * 0.36)
        var nozzle_size := Vector3(0.2, 0.12, 0.12) if absf(dir.x) > 0.5 else Vector3(0.12, 0.12, 0.2)
        _spawn_box(nozzle_center, nozzle_size, stone_dark)

        var stream_start := nozzle_center + Vector3(dir.x * 0.12, -0.08, dir.z * 0.12)
        var stream_end := center + Vector3(dir.x * 2.2, 0.58, dir.z * 2.2)
        _spawn_animated_water_stream(stream_start, stream_end, water, 11)

    _spawn_fountain_audio(center + Vector3(0.0, 1.25, 0.0))

func _spawn_asset_review_table() -> void:
    var wood_dark := Color(0.24, 0.19, 0.14)
    var wood_mid := Color(0.33, 0.26, 0.19)
    var metal := Color(0.19, 0.19, 0.2)
    var p := REVIEW_TABLE_POS

    # Stable platform near spawn for dropping/reviewing imported assets.
    _spawn_box(p + Vector3(0, 0.06, 0), Vector3(3.8, 0.12, 3.0), Color(0.42, 0.41, 0.38))

    # Table top and underside frame
    _spawn_box(p + Vector3(0, 1.08, 0), Vector3(2.8, 0.14, 1.75), wood_mid)
    _spawn_box(p + Vector3(0, 0.92, 0), Vector3(2.62, 0.08, 1.58), wood_dark)

    # Legs
    var leg_x := 1.22
    var leg_z := 0.72
    var legs: Array[Vector3] = [
        Vector3(-leg_x, 0.51, -leg_z),
        Vector3(leg_x, 0.51, -leg_z),
        Vector3(-leg_x, 0.51, leg_z),
        Vector3(leg_x, 0.51, leg_z)
    ]
    for leg in legs:
        _spawn_box(p + leg, Vector3(0.12, 1.02, 0.12), metal)

    # Small raised placement pad centered on the tabletop.
    _spawn_box(p + Vector3(0, 1.18, 0), Vector3(1.0, 0.06, 1.0), Color(0.48, 0.47, 0.43))

    var banana_scene := _load_packed_scene(BANANA_MODEL_PATH)
    if banana_scene:
        _spawn_preview_asset(banana_scene, p + Vector3(0.0, 1.24, 0.0), Vector3(0.6, 0.6, 0.6), 28.0)
    else:
        # Fallback placeholder so level generation never fails.
        _spawn_box(p + Vector3(0.0, 1.3, 0.0), Vector3(0.36, 0.12, 0.18), Color(0.92, 0.82, 0.23), false)

func _spawn_preview_asset(scene: PackedScene, position: Vector3, scale: Vector3, yaw_degrees: float) -> void:
    var instance := scene.instantiate()
    if instance is Node3D:
        var preview := instance as Node3D
        preview.position = position
        preview.scale = scale
        preview.rotation_degrees.y = yaw_degrees
    geometry_root.add_child(instance)

func _load_packed_scene(path: String) -> PackedScene:
    if not ResourceLoader.exists(path):
        return null
    var resource := ResourceLoader.load(path)
    if resource is PackedScene:
        return resource as PackedScene
    return null

func _load_glb_root_node(path: String) -> Node3D:
    var ext := path.get_extension().to_lower()
    if ext != "glb" and ext != "gltf":
        return null

    var gltf_doc := GLTFDocument.new()
    var gltf_state := GLTFState.new()
    var err := gltf_doc.append_from_file(path, gltf_state)
    if err != OK:
        return null

    var generated := gltf_doc.generate_scene(gltf_state)
    if generated is Node3D:
        return generated as Node3D
    return null

func _spawn_fountain_audio(position: Vector3) -> void:
    var stream := _load_audio_stream(FOUNTAIN_WATER_AUDIO_PATH)
    if stream == null:
        push_warning("Fountain audio missing: %s" % FOUNTAIN_WATER_AUDIO_PATH)
        return

    if stream is AudioStreamWAV:
        var wav := (stream as AudioStreamWAV).duplicate(true) as AudioStreamWAV
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        if wav.loop_end <= 0:
            wav.loop_end = int(maxf(wav.get_length(), 0.01) * float(wav.mix_rate))
        stream = wav
    elif stream is AudioStreamOggVorbis:
        var ogg := (stream as AudioStreamOggVorbis).duplicate(true) as AudioStreamOggVorbis
        ogg.loop = true
        stream = ogg
    elif stream is AudioStreamMP3:
        var mp3 := (stream as AudioStreamMP3).duplicate(true) as AudioStreamMP3
        mp3.loop = true
        stream = mp3

    var player := AudioStreamPlayer3D.new()
    player.name = "FountainWaterPlayer"
    player.stream = stream
    player.position = position
    player.volume_db = -3.5
    player.unit_size = 14.0
    player.max_distance = 96.0
    player.attenuation_filter_cutoff_hz = 3600.0
    player.attenuation_filter_db = -4.0
    geometry_root.add_child(player)
    if not player.is_connected("finished", Callable(self, "_on_fountain_audio_finished")):
        player.finished.connect(Callable(self, "_on_fountain_audio_finished").bind(player))
    player.play()

func _on_fountain_audio_finished(player: AudioStreamPlayer3D) -> void:
    if is_instance_valid(player):
        player.play()

func _load_audio_stream(path: String) -> AudioStream:
    var resource: Resource = null
    if ResourceLoader.exists(path):
        resource = ResourceLoader.load(path)
    if resource is AudioStream:
        return resource as AudioStream

    if not FileAccess.file_exists(path):
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

func _spawn_underground_room_fill_lights(room_floor_center: Vector3, room_w: float, room_d: float, room_h: float) -> void:
    var key_light := OmniLight3D.new()
    key_light.position = room_floor_center + Vector3(0.0, room_h * 0.5, 0.0)
    key_light.light_color = Color(1.0, 0.83, 0.64)
    key_light.light_energy = 7.8
    key_light.omni_range = maxf(room_w, room_d) * 0.66
    key_light.shadow_enabled = true
    key_light.shadow_bias = 0.08
    geometry_root.add_child(key_light)

    var fill_light := OmniLight3D.new()
    fill_light.position = room_floor_center + Vector3(0.0, room_h * 0.3, 0.0)
    fill_light.light_color = Color(0.68, 0.74, 0.85)
    fill_light.light_energy = 2.1
    fill_light.omni_range = maxf(room_w, room_d) * 0.52
    fill_light.shadow_enabled = false
    geometry_root.add_child(fill_light)

func _instantiate_dead_tree_source() -> Node3D:
    var tree: Node3D = null
    var scene := _dead_tree_scene
    if not scene:
        scene = _load_packed_scene(DEAD_TREE_MODEL_PATH)
        _dead_tree_scene = scene
    if scene:
        var scene_instance := scene.instantiate()
        if scene_instance is Node3D:
            tree = scene_instance as Node3D

    if not tree:
        tree = _load_glb_root_node(DEAD_TREE_MODEL_PATH)
    if not tree:
        push_warning("Could not load dead tree model from %s" % DEAD_TREE_MODEL_PATH)
        return null

    return tree

func _extract_dead_tree_candidates(source: Node3D) -> Array[Node3D]:
    var candidates: Array[Node3D] = []
    for child in source.get_children():
        if not (child is Node3D):
            continue
        var child_node := child as Node3D
        var child_bounds := _collect_mesh_bounds(child_node)
        if bool(child_bounds["valid"]):
            var duplicate := child_node.duplicate()
            if duplicate is Node3D:
                candidates.append(duplicate as Node3D)

    if candidates.is_empty():
        candidates.append(source)

    return candidates

func _spawn_underground_dead_trees(
    room_floor_center: Vector3,
    room_w: float,
    room_d: float,
    room_height: float,
    clear_point: Vector3 = Vector3.ZERO
) -> void:
    var source := _instantiate_dead_tree_source()
    if not source:
        return

    var templates := _extract_dead_tree_candidates(source)
    if templates.is_empty():
        return

    var spawn_x_min := room_floor_center.x - room_w * 0.5 + room_w * 0.16
    var spawn_x_max := room_floor_center.x + room_w * 0.5 - room_w * 0.16
    var spawn_z_min := room_floor_center.z - room_d * 0.5 + room_d * 0.16
    var spawn_z_max := room_floor_center.z + room_d * 0.5 - room_d * 0.16
    var room_x_min := room_floor_center.x - room_w * 0.5 + 0.85
    var room_x_max := room_floor_center.x + room_w * 0.5 - 0.85
    var room_z_min := room_floor_center.z - room_d * 0.5 + 0.85
    var room_z_max := room_floor_center.z + room_d * 0.5 - 0.85

    var cols := 5
    var rows := 4
    var cell_w := (spawn_x_max - spawn_x_min) / float(cols)
    var cell_d := (spawn_z_max - spawn_z_min) / float(rows)
    var spawn_points: Array[Vector2] = []
    for row in range(rows):
        for col in range(cols):
            var base_x := spawn_x_min + (float(col) + 0.5) * cell_w
            var base_z := spawn_z_min + (float(row) + 0.5) * cell_d
            var jitter_x := _rng.randf_range(-cell_w * 0.22, cell_w * 0.22)
            var jitter_z := _rng.randf_range(-cell_d * 0.22, cell_d * 0.22)
            spawn_points.append(Vector2(base_x + jitter_x, base_z + jitter_z))

    for i in range(spawn_points.size()):
        var point := spawn_points[i]
        if point.distance_to(Vector2(clear_point.x, clear_point.z)) < minf(cell_w, cell_d) * 0.75:
            continue
        var template := templates[i % templates.size()]
        var instance := template.duplicate()
        if not (instance is Node3D):
            continue
        var tree := instance as Node3D
        tree.position = Vector3.ZERO
        tree.rotation_degrees.y = _rng.randf_range(0.0, 360.0)

        var bounds := _collect_mesh_bounds(tree)
        var placement := Vector3(point.x, room_floor_center.y, point.y)
        if bool(bounds["valid"]):
            var aabb: AABB = bounds["aabb"]
            var source_height := maxf(aabb.size.y, 0.01)
            var scale_factor := clampf((room_height * 1.08) / source_height, 0.03, 24.0)
            scale_factor *= _rng.randf_range(0.92, 1.18)
            tree.scale *= scale_factor

            bounds = _collect_mesh_bounds(tree)
            if bool(bounds["valid"]):
                aabb = bounds["aabb"]
                var aabb_center := aabb.position + aabb.size * 0.5
                placement.x -= aabb_center.x
                placement.z -= aabb_center.z
                placement.y -= aabb.position.y

                var min_x := aabb.position.x + placement.x
                var max_x := min_x + aabb.size.x
                if min_x < room_x_min:
                    placement.x += room_x_min - min_x
                elif max_x > room_x_max:
                    placement.x -= max_x - room_x_max

                var min_z := aabb.position.z + placement.z
                var max_z := min_z + aabb.size.z
                if min_z < room_z_min:
                    placement.z += room_z_min - min_z
                elif max_z > room_z_max:
                    placement.z -= max_z - room_z_max
        else:
            tree.scale = Vector3.ONE * 3.8

        tree.position = placement
        geometry_root.add_child(tree)

func _collect_mesh_bounds(root: Node3D) -> Dictionary:
    var bounds := {
        "valid": false,
        "aabb": AABB()
    }
    _collect_mesh_bounds_recursive(root, Transform3D.IDENTITY, bounds)
    return bounds

func _collect_mesh_bounds_recursive(node: Node, parent_transform: Transform3D, bounds: Dictionary) -> void:
    var current_transform := parent_transform
    if node is Node3D:
        current_transform = parent_transform * (node as Node3D).transform

    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh:
            var mesh_aabb := mesh_instance.mesh.get_aabb()
            if mesh_aabb.size.length_squared() > 0.0:
                var transformed_aabb := _transform_aabb(mesh_aabb, current_transform)
                if not bool(bounds["valid"]):
                    bounds["aabb"] = transformed_aabb
                    bounds["valid"] = true
                else:
                    var merged: AABB = bounds["aabb"]
                    bounds["aabb"] = merged.merge(transformed_aabb)

    for child in node.get_children():
        _collect_mesh_bounds_recursive(child, current_transform, bounds)

func _transform_aabb(aabb: AABB, transform: Transform3D) -> AABB:
    var p := aabb.position
    var s := aabb.size
    var corners: Array[Vector3] = [
        transform * Vector3(p.x, p.y, p.z),
        transform * Vector3(p.x + s.x, p.y, p.z),
        transform * Vector3(p.x, p.y + s.y, p.z),
        transform * Vector3(p.x, p.y, p.z + s.z),
        transform * Vector3(p.x + s.x, p.y + s.y, p.z),
        transform * Vector3(p.x + s.x, p.y, p.z + s.z),
        transform * Vector3(p.x, p.y + s.y, p.z + s.z),
        transform * Vector3(p.x + s.x, p.y + s.y, p.z + s.z)
    ]

    var transformed := AABB(corners[0], Vector3.ZERO)
    for i in range(1, corners.size()):
        transformed = transformed.expand(corners[i])
    return transformed

func _setup_asylum_materials() -> void:
    _asylum_exterior_material = _create_textured_material(
        ASYLUM_EXTERIOR_DIFFUSE_PATH,
        ASYLUM_EXTERIOR_NORMAL_PATH,
        ASYLUM_EXTERIOR_ROUGHNESS_PATH,
        Color(1.0, 1.0, 1.0),
        0.9
    )
    _asylum_exterior_material.emission_enabled = true
    _asylum_exterior_material.emission = Color(0.08, 0.08, 0.08)
    _asylum_interior_material = _create_textured_material(
        ASYLUM_INTERIOR_DIFFUSE_PATH,
        ASYLUM_INTERIOR_NORMAL_PATH,
        ASYLUM_INTERIOR_ROUGHNESS_PATH,
        Color(0.98, 0.98, 0.97),
        0.88
    )
    _asylum_floor_material = _create_textured_material(
        ASYLUM_FLOOR_DIFFUSE_PATH,
        ASYLUM_FLOOR_NORMAL_PATH,
        ASYLUM_FLOOR_ROUGHNESS_PATH,
        Color(0.92, 0.92, 0.92),
        0.78,
        Vector3(0.16, 0.16, 0.08)
    )

    _asylum_window_material = StandardMaterial3D.new()
    _asylum_window_material.albedo_color = Color(0.16, 0.2, 0.24)
    _asylum_window_material.roughness = 0.2
    _asylum_window_material.metallic = 0.06
    _asylum_window_material.emission_enabled = true
    _asylum_window_material.emission = Color(0.09, 0.12, 0.15)
    _asylum_window_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

    _space_panel_materials.clear()
    _space_panel_materials["0:1"] = _create_panel_image_material(SPACE1_TEXTURE_PATH)
    _space_panel_materials["1:4"] = _create_panel_image_material(SPACE2_TEXTURE_PATH)
    _space_panel_materials["2:3"] = _create_panel_image_material(SPACE3_TEXTURE_PATH)
    _space4_house_material = _create_world_wrap_material(SPACE4_TEXTURE_PATH, Color(1, 1, 1), 0.9, 0.08)
    _space4_house_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
    _space4_house_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _space4_house_material.disable_fog = true
    _space4_house_material.disable_ambient_light = true

func _create_textured_material(
    diffuse_path: String,
    normal_path: String,
    roughness_path: String,
    tint: Color,
    base_roughness: float,
    uv_scale: Vector3 = Vector3.ONE * ASYLUM_TEXTURE_WORLD_SCALE
) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = base_roughness
    mat.metallic = 0.0
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    # World-space triplanar keeps texture density consistent across all wall/floor sizes.
    mat.uv1_triplanar = true
    mat.uv1_world_triplanar = true
    mat.uv1_scale = uv_scale

    var diffuse_tex := _load_texture_2d(diffuse_path)
    if diffuse_tex:
        mat.albedo_texture = diffuse_tex

    var normal_tex := _load_texture_2d(normal_path)
    if normal_tex:
        mat.normal_enabled = true
        mat.normal_texture = normal_tex
        mat.normal_scale = 0.4

    var roughness_tex := _load_texture_2d(roughness_path)
    if roughness_tex:
        mat.roughness_texture = roughness_tex
        mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

    return mat

func _load_texture_2d(path: String) -> Texture2D:
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var resource := ResourceLoader.load(path)
    if resource is Texture2D:
        return resource as Texture2D
    return null

func _create_panel_image_material(texture_path: String) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 1.0, 1.0)
    mat.roughness = 0.85
    mat.metallic = 0.0
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
    var tex := _load_texture_2d(texture_path)
    if tex:
        mat.albedo_texture = tex
    return mat

func _create_world_wrap_material(texture_path: String, tint: Color, roughness: float, scale: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = roughness
    mat.metallic = 0.0
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mat.uv1_triplanar = true
    mat.uv1_world_triplanar = true
    mat.uv1_scale = Vector3.ONE * scale
    var tex := _load_texture_2d(texture_path)
    if tex:
        mat.albedo_texture = tex
    return mat

func _spawn_asylum(front_z: float) -> void:
    var building_w := 44.0
    var building_d := 28.0
    var wall_t := 0.45
    var floor_h := 3.35
    var levels := 3
    var total_h := floor_h * levels
    var center_z := front_z + building_d * 0.5
    var facade_color := Color(0.55, 0.55, 0.53)
    var trim_color := Color(0.25, 0.25, 0.28)
    var exterior_mat := _asylum_exterior_material
    var interior_mat := _asylum_interior_material
    var floor_mat := _asylum_floor_material

    # Main shell perimeter walls (hollow interior). Side walls include open passages to stair towers.
    var stair_passage_d := 2.6
    var side_segment_d := (building_d - stair_passage_d) * 0.5
    var left_wall_x := -building_w * 0.5 + wall_t * 0.5
    var right_wall_x := building_w * 0.5 - wall_t * 0.5
    var front_seg_center_z := front_z + side_segment_d * 0.5
    var back_seg_center_z := front_z + building_d - side_segment_d * 0.5
    _spawn_box(Vector3(left_wall_x, total_h * 0.5, front_seg_center_z), Vector3(wall_t, total_h, side_segment_d), facade_color, true, exterior_mat)
    _spawn_box(Vector3(left_wall_x, total_h * 0.5, back_seg_center_z), Vector3(wall_t, total_h, side_segment_d), facade_color, true, exterior_mat)
    _spawn_box(Vector3(right_wall_x, total_h * 0.5, front_seg_center_z), Vector3(wall_t, total_h, side_segment_d), facade_color, true, exterior_mat)
    _spawn_box(Vector3(right_wall_x, total_h * 0.5, back_seg_center_z), Vector3(wall_t, total_h, side_segment_d), facade_color, true, exterior_mat)
    var doorway_w := 4.8
    var doorway_h := 3.4
    var front_segment_w := (building_w - doorway_w) * 0.5
    _spawn_box(
        Vector3(-doorway_w * 0.5 - front_segment_w * 0.5, total_h * 0.5, front_z + wall_t * 0.5),
        Vector3(front_segment_w, total_h, wall_t),
        facade_color,
        true,
        exterior_mat
    )
    _spawn_box(
        Vector3(doorway_w * 0.5 + front_segment_w * 0.5, total_h * 0.5, front_z + wall_t * 0.5),
        Vector3(front_segment_w, total_h, wall_t),
        facade_color,
        true,
        exterior_mat
    )
    _spawn_box(
        Vector3(0, doorway_h + (total_h - doorway_h) * 0.5, front_z + wall_t * 0.5),
        Vector3(doorway_w, total_h - doorway_h, wall_t),
        facade_color,
        true,
        exterior_mat
    )
    _spawn_box(Vector3(0, total_h * 0.5, front_z + building_d - wall_t * 0.5), Vector3(building_w, total_h, wall_t), facade_color, true, exterior_mat)
    _spawn_box(Vector3(0, total_h + 0.35, center_z), Vector3(building_w + 1.2, 0.7, building_d + 1.2), trim_color, true, exterior_mat)

    _spawn_asylum_windows(front_z, building_w, building_d, floor_h, levels, wall_t)

    # Front doorway frame + large two-panel hinged door.
    _spawn_box(Vector3(-2.85, 1.7, front_z + 0.75), Vector3(0.6, 3.4, 0.9), Color(0.48, 0.48, 0.46), true, interior_mat)
    _spawn_box(Vector3(2.85, 1.7, front_z + 0.75), Vector3(0.6, 3.4, 0.9), Color(0.48, 0.48, 0.46), true, interior_mat)
    _spawn_box(Vector3(0, 3.72, front_z + 0.75), Vector3(6.3, 0.64, 0.9), Color(0.48, 0.48, 0.46), true, interior_mat)
    _spawn_interactable_door(
        Vector3(-doorway_w * 0.5 + 0.05, doorway_h * 0.5, front_z + wall_t * 0.52),
        Vector3(2.35, doorway_h, 0.16),
        Color(0.14, 0.14, 0.15),
        1.0,
        1.175
    )
    _spawn_interactable_door(
        Vector3(doorway_w * 0.5 - 0.05, doorway_h * 0.5, front_z + wall_t * 0.52),
        Vector3(2.35, doorway_h, 0.16),
        Color(0.14, 0.14, 0.15),
        -1.0,
        -1.175
    )

    # Floors and corridors
    for level in range(levels):
        var y_floor := level * floor_h
        _spawn_box(
            Vector3(0, y_floor + 0.08, center_z),
            Vector3(building_w - 0.9, 0.16, building_d - 0.9),
            Color(0.34, 0.34, 0.33),
            true,
            floor_mat
        )

        # Exactly 12 rooms per level: 6 on each side of the corridor
        _spawn_level_rooms(front_z, building_w, building_d, wall_t, y_floor, floor_h, level, interior_mat)

        # Bridge floor between corridor edge and each stair tower opening.
        var side_values: Array[float] = [-1.0, 1.0]
        for side in side_values:
            var bridge_x := side * (building_w * 0.5 + 1.55)
            _spawn_box(
                Vector3(bridge_x, y_floor + 0.06, center_z),
                Vector3(4.0, 0.24, 4.2),
                Color(0.34, 0.34, 0.33),
                true,
                floor_mat
            )

    # Flat entry approach (stairs removed): prevents trapping/drop on exit.
    _spawn_box(
        Vector3(0, 0.08, front_z - 1.8),
        Vector3(12.8, 0.16, 4.4),
        Color(0.5, 0.5, 0.47),
        true,
        floor_mat
    )

    # End stair towers: one at each building end for vertical circulation
    _spawn_side_stair_tower(-1.0, front_z, building_w, building_d, floor_h, levels, exterior_mat, floor_mat)
    _spawn_side_stair_tower(1.0, front_z, building_w, building_d, floor_h, levels, exterior_mat, floor_mat)

    # Imposing central raised mass
    _spawn_box(Vector3(0, total_h + 3.3, front_z + 10.5), Vector3(14.0, 6.6, 9.2), Color(0.51, 0.51, 0.49), true, exterior_mat)
    _spawn_box(Vector3(0, total_h + 6.9, front_z + 10.5), Vector3(14.8, 0.8, 10.0), Color(0.23, 0.23, 0.25), true, exterior_mat)

func _spawn_asylum_windows(front_z: float, building_w: float, building_d: float, floor_h: float, levels: int, wall_t: float) -> void:
    var cols := 10
    var min_x := -building_w * 0.5 + 2.4
    var max_x := building_w * 0.5 - 2.4
    var front_z_panel := front_z - 0.08
    var back_z_panel := front_z + building_d + 0.08
    var window_size := Vector3(1.75, 1.15, 0.12)
    var side_rows := 6
    var min_z := front_z + 2.2
    var max_z := front_z + building_d - 2.2
    var left_x_panel := -building_w * 0.5 - 0.08
    var right_x_panel := building_w * 0.5 + 0.08
    var side_window_size := Vector3(0.12, 1.15, 1.75)

    for level in range(levels):
        var y := level * floor_h + floor_h * 0.58
        for i in range(cols):
            var t := float(i) / float(cols - 1)
            var x := lerpf(min_x, max_x, t)
            if level == 0 and absf(x) < 3.6:
                continue
            _spawn_box(Vector3(x, y, front_z_panel), window_size, Color(0.2, 0.24, 0.28), false, _asylum_window_material)
            _spawn_box(Vector3(x, y, back_z_panel), window_size, Color(0.2, 0.24, 0.28), false, _asylum_window_material)

        for i in range(side_rows):
            var tz := float(i) / float(side_rows - 1)
            var z := lerpf(min_z, max_z, tz)
            _spawn_box(Vector3(left_x_panel, y, z), side_window_size, Color(0.2, 0.24, 0.28), false, _asylum_window_material)
            _spawn_box(Vector3(right_x_panel, y, z), side_window_size, Color(0.2, 0.24, 0.28), false, _asylum_window_material)

func _spawn_level_rooms(
    front_z: float,
    building_w: float,
    building_d: float,
    wall_t: float,
    y_floor: float,
    floor_h: float,
    level: int,
    interior_mat: Material
) -> void:
    var corridor_w := 4.2
    var center_z := front_z + building_d * 0.5
    var row_depth := (building_d - corridor_w - wall_t * 2.0) * 0.5
    var room_count_side := 6
    var usable_w := building_w - wall_t * 2.0
    var room_w := usable_w / float(room_count_side)
    var level_room_number := 0
    # Slightly overlap floor/ceiling planes to eliminate seam slivers that pop with camera angle.
    var wall_h := floor_h + 0.08
    var top_y := y_floor + wall_h * 0.5 - 0.04

    # Corridor boundary walls (with repeated door gaps to rooms)
    var side_values: Array[float] = [-1.0, 1.0]
    for side in side_values:
        var row_center_z: float = center_z + side * (corridor_w * 0.5 + row_depth * 0.5)
        var corridor_edge_z: float = center_z + side * (corridor_w * 0.5)

        for i in range(room_count_side):
            var room_center_x := -usable_w * 0.5 + room_w * 0.5 + room_w * float(i)
            var is_front_ground := level == 0 and side < 0.0
            var is_entry_lobby_room := is_front_ground and (i == 2 or i == 3)

            # Room back wall section
            var back_z: float = row_center_z + side * (row_depth * 0.5 - wall_t * 0.5)
            if not is_entry_lobby_room:
                _spawn_box(Vector3(room_center_x, top_y, back_z), Vector3(room_w - 0.08, wall_h, wall_t), Color(0.58, 0.58, 0.56), true, interior_mat)

            # Corridor-side wall split into two pieces with a doorway gap
            var door_w := 1.25
            var seg_w := (room_w - door_w) * 0.5
            var left_x := room_center_x - (door_w * 0.5 + seg_w * 0.5)
            var right_x := room_center_x + (door_w * 0.5 + seg_w * 0.5)
            var room_key := ""
            var room_texture_material: Material = null
            if not is_entry_lobby_room:
                _spawn_box(Vector3(left_x, top_y, corridor_edge_z), Vector3(seg_w, wall_h, wall_t), Color(0.58, 0.58, 0.56), true, interior_mat)
                _spawn_box(Vector3(right_x, top_y, corridor_edge_z), Vector3(seg_w, wall_h, wall_t), Color(0.58, 0.58, 0.56), true, interior_mat)

                level_room_number += 1
                room_key = str(level) + ":" + str(level_room_number)
                if _space_panel_materials.has(room_key):
                    room_texture_material = _space_panel_materials[room_key]
                    _spawn_room_texture_wrap(
                        room_center_x,
                        row_center_z,
                        room_w,
                        row_depth,
                        corridor_edge_z,
                        back_z,
                        side,
                        y_floor,
                        floor_h,
                        wall_t,
                        door_w,
                        room_texture_material
                    )

                # Room number: high and on the right side of each doorway (relative to corridor-facing view).
                var right_side_x_dir := 1.0 if side < 0.0 else -1.0
                var number_x := room_center_x + right_side_x_dir * (door_w * 0.5 + 0.26)
                var number_y := y_floor + floor_h - 0.58
                var corridor_face_z := corridor_edge_z - side * (wall_t * 0.5 + 0.03)
                _spawn_room_number(level_room_number, Vector3(number_x, number_y, corridor_face_z), side)

            # Interior divider between rooms (skip final room)
            if i < room_count_side - 1:
                var div_x := room_center_x + room_w * 0.5 - wall_t * 0.5
                var is_lobby_center_divider := is_front_ground and i == 2
                if not is_lobby_center_divider:
                    _spawn_box(Vector3(div_x, top_y, row_center_z), Vector3(wall_t, wall_h, row_depth), Color(0.56, 0.56, 0.54), true, interior_mat)

            # "Monitor" panel for regular rooms only.
            if not is_entry_lobby_room and room_texture_material == null:
                var panel_w := minf(room_w * 0.48, 1.6)
                var panel_h := 0.62
                var panel_d := 0.06
                var panel_z := back_z - side * (wall_t * 0.5 + panel_d * 0.5 + 0.01)
                var side_index := 0 if side < 0.0 else 1
                var room_index := level * room_count_side * 2 + side_index * room_count_side + i
                var hue := fposmod(float(room_index) * 0.113, 1.0)
                var panel_color := Color.from_hsv(hue, 0.48, 0.72, 1.0)
                _spawn_box(
                    Vector3(room_center_x, y_floor + 1.45, panel_z),
                    Vector3(panel_w, panel_h, panel_d),
                    panel_color,
                    false
                )

func _spawn_room_texture_wrap(
    room_center_x: float,
    room_center_z: float,
    room_w: float,
    row_depth: float,
    corridor_edge_z: float,
    back_z: float,
    side: float,
    y_floor: float,
    floor_h: float,
    wall_t: float,
    door_w: float,
    material: Material
) -> void:
    if material == null:
        return

    var surface_t := 0.03
    var inset := 0.012
    var wall_h := floor_h - 0.18
    var wall_y := y_floor + floor_h * 0.5

    var interior_x_min := room_center_x - room_w * 0.5 + wall_t + inset
    var interior_x_max := room_center_x + room_w * 0.5 - wall_t - inset
    var interior_z_front := corridor_edge_z + side * (wall_t + inset)
    var interior_z_back := back_z - side * (wall_t + inset)
    var room_inner_w := maxf(interior_x_max - interior_x_min, 0.2)
    var room_inner_d := maxf(absf(interior_z_back - interior_z_front), 0.2)
    var room_mid_z := (interior_z_front + interior_z_back) * 0.5

    # Floor and ceiling overlays.
    _spawn_box(
        Vector3(room_center_x, y_floor + 0.165, room_mid_z),
        Vector3(room_inner_w, surface_t, room_inner_d),
        Color.WHITE,
        false,
        material
    )
    _spawn_box(
        Vector3(room_center_x, y_floor + floor_h - 0.165, room_mid_z),
        Vector3(room_inner_w, surface_t, room_inner_d),
        Color.WHITE,
        false,
        material
    )

    # Back wall overlay.
    var back_wall_z := interior_z_back - side * (surface_t * 0.5)
    _spawn_box(
        Vector3(room_center_x, wall_y, back_wall_z + side * 0.001),
        Vector3(room_inner_w, wall_h, surface_t),
        Color.WHITE,
        false,
        material
    )

    # Side wall overlays.
    var side_wall_len := maxf(room_inner_d + surface_t * 0.6, 0.2)
    var left_wall_x := interior_x_min + surface_t * 0.5
    var right_wall_x := interior_x_max - surface_t * 0.5
    _spawn_box(
        Vector3(left_wall_x, wall_y, room_mid_z),
        Vector3(surface_t, wall_h, side_wall_len),
        Color.WHITE,
        false,
        material
    )
    _spawn_box(
        Vector3(right_wall_x, wall_y, room_mid_z),
        Vector3(surface_t, wall_h, side_wall_len),
        Color.WHITE,
        false,
        material
    )

    # Corridor-side wall overlay split around doorway.
    var front_wall_z := interior_z_front + side * (surface_t * 0.5)
    var seg_w := maxf((room_inner_w - door_w) * 0.5, 0.12)
    var front_seg_w := maxf(seg_w, 0.12)
    var left_seg_x := room_center_x - (door_w * 0.5 + seg_w * 0.5)
    var right_seg_x := room_center_x + (door_w * 0.5 + seg_w * 0.5)
    _spawn_box(
        Vector3(left_seg_x, wall_y, front_wall_z - side * 0.001),
        Vector3(front_seg_w, wall_h, surface_t),
        Color.WHITE,
        false,
        material
    )
    _spawn_box(
        Vector3(right_seg_x, wall_y, front_wall_z - side * 0.001),
        Vector3(front_seg_w, wall_h, surface_t),
        Color.WHITE,
        false,
        material
    )

    # Doorway jamb overlays (inside door reveal) to eliminate unwrapped strips.
    var jamb_d := wall_t + 0.02
    var jamb_w := 0.06
    var jamb_x_l := room_center_x - (door_w * 0.5) + jamb_w * 0.5
    var jamb_x_r := room_center_x + (door_w * 0.5) - jamb_w * 0.5
    var jamb_mid_z := corridor_edge_z + side * (jamb_d * 0.5)
    _spawn_box(
        Vector3(jamb_x_l, wall_y, jamb_mid_z),
        Vector3(jamb_w, wall_h, jamb_d),
        Color.WHITE,
        false,
        material
    )
    _spawn_box(
        Vector3(jamb_x_r, wall_y, jamb_mid_z),
        Vector3(jamb_w, wall_h, jamb_d),
        Color.WHITE,
        false,
        material
    )

func _spawn_room_number(number: int, position: Vector3, side: float) -> void:
    var sign := MeshInstance3D.new()
    var text_mesh := TextMesh.new()
    text_mesh.text = str(number)
    text_mesh.pixel_size = 0.02
    text_mesh.depth = 0.015
    text_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    text_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    sign.mesh = text_mesh
    sign.position = position
    sign.scale = Vector3.ONE * 0.92
    # Face the corridor on both wings.
    sign.rotation_degrees.y = 0.0 if side < 0.0 else 180.0

    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.93, 0.93, 0.9)
    mat.roughness = 0.85
    mat.metallic = 0.0
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sign.material_override = mat

    geometry_root.add_child(sign)

func _spawn_side_stair_tower(
    side: float,
    front_z: float,
    building_w: float,
    building_d: float,
    floor_h: float,
    levels: int,
    exterior_mat: Material,
    floor_mat: Material
) -> void:
    var tower_w := 10.8
    var tower_d := 16.4
    var wall_h_total := floor_h * float(levels)
    var center_z := front_z + building_d * 0.5
    var tower_x := side * (building_w * 0.5 + tower_w * 0.5 - 0.1)
    var tower_color := Color(0.5, 0.5, 0.49)
    var floor_color := Color(0.36, 0.36, 0.35)
    var wt := 0.35

    # Hollow tower shell with an open side facing the main corridor.
    var inner_open_d := 5.2
    var wall_seg_d := (tower_d - inner_open_d) * 0.5
    var front_seg_z := center_z - tower_d * 0.5 + wall_seg_d * 0.5
    var back_seg_z := center_z + tower_d * 0.5 - wall_seg_d * 0.5
    var outer_wall_x := tower_x + side * (tower_w * 0.5 - wt * 0.5)
    var inner_wall_x := tower_x - side * (tower_w * 0.5 - wt * 0.5)
    _spawn_box(Vector3(outer_wall_x, wall_h_total * 0.5, center_z), Vector3(wt, wall_h_total, tower_d), tower_color, true, exterior_mat)
    _spawn_box(Vector3(inner_wall_x, wall_h_total * 0.5, front_seg_z), Vector3(wt, wall_h_total, wall_seg_d), tower_color, true, exterior_mat)
    _spawn_box(Vector3(inner_wall_x, wall_h_total * 0.5, back_seg_z), Vector3(wt, wall_h_total, wall_seg_d), tower_color, true, exterior_mat)
    _spawn_box(Vector3(tower_x, wall_h_total * 0.5, center_z - tower_d * 0.5 + wt * 0.5), Vector3(tower_w, wall_h_total, wt), tower_color, true, exterior_mat)
    _spawn_box(Vector3(tower_x, wall_h_total * 0.5, center_z + tower_d * 0.5 - wt * 0.5), Vector3(tower_w, wall_h_total, wt), tower_color, true, exterior_mat)
    _spawn_box(Vector3(tower_x, wall_h_total + 0.2, center_z), Vector3(tower_w + 0.4, 0.4, tower_d + 0.4), Color(0.24, 0.24, 0.26), true, exterior_mat)

    # Collision-stable floors with explicit stairwell openings.
    var floor_thickness := 0.24
    var tower_floor_w := tower_w - 0.9
    var tower_floor_d := tower_d - 0.9
    var stair_w := 1.35
    var ramp_w := 1.75
    var lane_outer_x := tower_x + side * 3.5
    var lane_inner_x := tower_x + side * 1.7
    var south_z := center_z - 5.2
    var north_z := center_z + 5.2
    var run_len := north_z - south_z
    var step_count := 18
    var riser := floor_h / float(step_count)
    var tread := run_len / float(step_count)
    var pitch := rad_to_deg(atan(floor_h / run_len))

    # Ground level slab is fully solid.
    _spawn_box(Vector3(tower_x, floor_thickness * 0.5, center_z), Vector3(tower_floor_w, floor_thickness, tower_floor_d), floor_color, true, floor_mat)

    # Level 1: opening above the upper half of the first flight.
    _spawn_floor_with_rect_hole(
        tower_x,
        floor_h + floor_thickness * 0.5,
        center_z,
        tower_floor_w,
        floor_thickness,
        tower_floor_d,
        lane_outer_x - 1.35,
        lane_outer_x + 1.35,
        center_z - 1.4,
        north_z + 1.1,
        floor_color,
        floor_mat
    )

    # Level 2: opening above the upper half of the second flight.
    _spawn_floor_with_rect_hole(
        tower_x,
        floor_h * 2.0 + floor_thickness * 0.5,
        center_z,
        tower_floor_w,
        floor_thickness,
        tower_floor_d,
        lane_inner_x - 1.35,
        lane_inner_x + 1.35,
        south_z - 1.1,
        center_z + 1.4,
        floor_color,
        floor_mat
    )

    # Explicit switchback/arrival landings at level boundaries.
    var landing_w: float = absf(lane_outer_x - lane_inner_x) + 2.6
    _spawn_box(
        Vector3((lane_outer_x + lane_inner_x) * 0.5, floor_h + floor_thickness * 0.5, north_z + 1.1),
        Vector3(landing_w, floor_thickness, 2.2),
        floor_color,
        true,
        floor_mat
    )
    _spawn_box(
        Vector3((lane_outer_x + lane_inner_x) * 0.5, floor_h * 2.0 + floor_thickness * 0.5, south_z - 1.1),
        Vector3(landing_w, floor_thickness, 2.2),
        floor_color,
        true,
        floor_mat
    )

    # First flight: level 0 south -> level 1 north (outer lane).
    _spawn_stair_flight(lane_outer_x, 0.0, south_z, stair_w, tread, riser, step_count, 1.0, floor_mat)
    _spawn_ramp(
        Vector3(lane_outer_x, floor_h * 0.5, south_z + run_len * 0.5),
        Vector3(ramp_w, 0.48, run_len + 0.12),
        -pitch,
        Color(0, 0, 0),
        false,
        true
    )

    # Second flight: level 1 north -> level 2 south (inner lane), offset from the first.
    _spawn_stair_flight(lane_inner_x, floor_h, north_z, stair_w, tread, riser, step_count, -1.0, floor_mat)
    _spawn_ramp(
        Vector3(lane_inner_x, floor_h + floor_h * 0.5, north_z - run_len * 0.5),
        Vector3(ramp_w, 0.48, run_len + 0.12),
        pitch,
        Color(0, 0, 0),
        false,
        true
    )

func _spawn_stair_flight(
    x: float,
    y_base: float,
    z_start: float,
    width: float,
    tread: float,
    riser: float,
    step_count: int,
    dir: float,
    material_override: Material = null
) -> void:
    for i in range(step_count):
        var y := y_base + riser * 0.5 + float(i) * riser
        var z := z_start + dir * (float(i) * tread + tread * 0.5)
        _spawn_box(Vector3(x, y, z), Vector3(width, riser, tread + 0.03), Color(0.43, 0.43, 0.42), false, material_override)

func _spawn_floor_with_rect_hole(
    center_x: float,
    y: float,
    center_z: float,
    total_w: float,
    thickness: float,
    total_d: float,
    hole_x_min: float,
    hole_x_max: float,
    hole_z_min: float,
    hole_z_max: float,
    color: Color,
    material_override: Material = null,
    has_collision: bool = true
) -> void:
    var x_min: float = center_x - total_w * 0.5
    var x_max: float = center_x + total_w * 0.5
    var z_min: float = center_z - total_d * 0.5
    var z_max: float = center_z + total_d * 0.5

    var hx0: float = clampf(minf(hole_x_min, hole_x_max), x_min + 0.08, x_max - 0.08)
    var hx1: float = clampf(maxf(hole_x_min, hole_x_max), x_min + 0.08, x_max - 0.08)
    var hz0: float = clampf(minf(hole_z_min, hole_z_max), z_min + 0.08, z_max - 0.08)
    var hz1: float = clampf(maxf(hole_z_min, hole_z_max), z_min + 0.08, z_max - 0.08)
    if hx1 <= hx0 or hz1 <= hz0:
        _spawn_box(Vector3(center_x, y, center_z), Vector3(total_w, thickness, total_d), color, has_collision, material_override)
        return

    var left_w: float = hx0 - x_min
    if left_w > 0.14:
        _spawn_box(Vector3(x_min + left_w * 0.5, y, center_z), Vector3(left_w, thickness, total_d), color, has_collision, material_override)

    var right_w: float = x_max - hx1
    if right_w > 0.14:
        _spawn_box(Vector3(hx1 + right_w * 0.5, y, center_z), Vector3(right_w, thickness, total_d), color, has_collision, material_override)

    var center_w: float = hx1 - hx0
    var front_d: float = hz0 - z_min
    if center_w > 0.14 and front_d > 0.14:
        _spawn_box(Vector3((hx0 + hx1) * 0.5, y, z_min + front_d * 0.5), Vector3(center_w, thickness, front_d), color, has_collision, material_override)

    var back_d: float = z_max - hz1
    if center_w > 0.14 and back_d > 0.14:
        _spawn_box(Vector3((hx0 + hx1) * 0.5, y, hz1 + back_d * 0.5), Vector3(center_w, thickness, back_d), color, has_collision, material_override)

func _spawn_interactable_door(
    position: Vector3,
    size: Vector3,
    color: Color,
    open_direction: float,
    hinge_offset_x: float,
    yaw_degrees: float = 0.0,
    start_locked: bool = false,
    material_override: Material = null
) -> StaticBody3D:
    var door := StaticBody3D.new()
    door.position = position
    door.rotation_degrees.y = yaw_degrees
    door.set_script(DOOR_SCRIPT)
    door.set("open_direction", open_direction)
    door.set("open_angle_degrees", 108.0)
    door.set("open_speed", 7.0)
    door.set("is_locked", start_locked)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    collision.position.x = hinge_offset_x
    door.add_child(collision)

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position.x = hinge_offset_x

    if material_override:
        mesh_instance.material_override = material_override
    else:
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 0.9
        material.metallic = 0.0
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        mesh_instance.material_override = material

    door.add_child(mesh_instance)
    geometry_root.add_child(door)
    return door

func _make_unlit_color_material(color: Color) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = "shader_type spatial;\nrender_mode unshaded, fog_disabled;\nuniform vec4 u_color : source_color;\nvoid fragment() {\n\tALBEDO = u_color.rgb;\n\tALPHA = u_color.a;\n}"
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("u_color", color)
    return material

func _make_torch_lit_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    material.metallic = 0.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.set_flag(BaseMaterial3D.FLAG_DISABLE_AMBIENT_LIGHT, true)
    material.set_flag(BaseMaterial3D.FLAG_DISABLE_FOG, true)
    return material

func _make_jet_black_unlit_material() -> ShaderMaterial:
    var material := _make_unlit_color_material(Color(0.0, 0.0, 0.0, 1.0))
    return material

func _spawn_street_light(base: Vector3) -> void:
    var arm_dir := -1.0 if base.x > 0.0 else 1.0
    _spawn_box(base + Vector3(0, 2.0, 0), Vector3(0.12, 4.0, 0.12), Color(0.2, 0.2, 0.2))
    _spawn_box(base + Vector3(0.35 * arm_dir, 3.9, 0), Vector3(0.8, 0.08, 0.08), Color(0.2, 0.2, 0.2))

    var light := OmniLight3D.new()
    light.position = base + Vector3(0.72 * arm_dir, 3.75, 0)
    light.light_color = Color(1.0, 0.94, 0.74)
    light.light_energy = _rng.randf_range(0.25, 0.42)
    light.omni_range = 11.0
    light.shadow_enabled = true
    light.shadow_bias = 0.1
    geometry_root.add_child(light)

func _spawn_wall_torch(position: Vector3, yaw_degrees: float) -> void:
    var torch := Node3D.new()
    torch.position = position
    torch.rotation_degrees.y = yaw_degrees

    var handle := MeshInstance3D.new()
    var handle_mesh := BoxMesh.new()
    handle_mesh.size = Vector3(0.08, 0.42, 0.08)
    handle.mesh = handle_mesh
    handle.position = Vector3(0.0, -0.06, 0.0)
    var handle_mat := StandardMaterial3D.new()
    handle_mat.albedo_color = Color(0.14, 0.1, 0.08)
    handle_mat.roughness = 0.95
    handle_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    handle.material_override = handle_mat
    torch.add_child(handle)

    var flame := MeshInstance3D.new()
    var flame_mesh := SphereMesh.new()
    flame_mesh.radius = 0.07
    flame_mesh.height = 0.16
    flame_mesh.radial_segments = 6
    flame_mesh.rings = 4
    flame.mesh = flame_mesh
    flame.position = Vector3(0.0, 0.18, 0.0)
    var flame_mat := StandardMaterial3D.new()
    flame_mat.albedo_color = Color(1.0, 0.65, 0.24)
    flame_mat.emission_enabled = true
    flame_mat.emission = Color(1.0, 0.54, 0.18)
    flame_mat.emission_energy_multiplier = 1.2
    flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flame_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    flame.material_override = flame_mat
    torch.add_child(flame)

    var light := OmniLight3D.new()
    light.position = Vector3(0.0, 0.18, 0.0)
    light.light_color = Color(1.0, 0.66, 0.36)
    light.light_energy = 3.8
    light.omni_range = 18.0
    light.shadow_enabled = false
    torch.add_child(light)

    geometry_root.add_child(torch)

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
        var collision_shape := BoxShape3D.new()
        collision_shape.size = size
        collision.shape = collision_shape
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

func _spawn_rotated_box(
    position: Vector3,
    size: Vector3,
    rotation_degrees: Vector3,
    color: Color,
    has_collision: bool = true,
    material_override: Material = null
) -> void:
    var node := StaticBody3D.new()
    node.position = position
    node.rotation_degrees = rotation_degrees

    if has_collision:
        var collision := CollisionShape3D.new()
        var collision_shape := BoxShape3D.new()
        collision_shape.size = size
        collision.shape = collision_shape
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

func _spawn_ring_wall(
    center: Vector3,
    radius: float,
    wall_height: float,
    wall_thickness: float,
    segments: int,
    color: Color,
    has_collision: bool = true
) -> void:
    var seg_count := maxi(segments, 6)
    var seg_len := TAU * radius / float(seg_count) * 1.05
    for i in range(seg_count):
        var angle := TAU * float(i) / float(seg_count)
        var px := center.x + cos(angle) * radius
        var pz := center.z + sin(angle) * radius
        _spawn_rotated_box(
            Vector3(px, center.y, pz),
            Vector3(wall_thickness, wall_height, seg_len),
            Vector3(0, rad_to_deg(-angle), 0),
            color,
            has_collision
        )

func _spawn_animated_water_stream(start: Vector3, end: Vector3, color: Color, droplet_count: int) -> void:
    var count := maxi(droplet_count, 2)
    var distance_xz := Vector2(start.x, start.z).distance_to(Vector2(end.x, end.z))
    var base_control := start.lerp(end, 0.34)
    base_control.y = maxf(start.y, end.y) + 0.18 + distance_xz * 0.08

    for i in range(count):
        var droplet := MeshInstance3D.new()
        var droplet_mesh := BoxMesh.new()
        droplet_mesh.size = Vector3(0.085, 0.085, 0.085)
        droplet.mesh = droplet_mesh

        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 0.18
        material.metallic = 0.0
        material.emission_enabled = true
        material.emission = color.lightened(0.15)
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        droplet.material_override = material

        var t_start := float(i) / float(count)
        droplet.position = start.lerp(end, t_start)
        geometry_root.add_child(droplet)

        _water_stream_droplets.append({
            "node": droplet,
            "start": start,
            "control": base_control + Vector3(
                _rng.randf_range(-0.03, 0.03),
                _rng.randf_range(-0.04, 0.04),
                _rng.randf_range(-0.03, 0.03)
            ),
            "end": end,
            "t": t_start,
            "speed": 0.85 + _rng.randf_range(0.0, 0.22)
        })

func _quadratic_bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
    var u := 1.0 - t
    return u * u * a + 2.0 * u * t * b + t * t * c

func _spawn_cylinder(
    position: Vector3,
    radius: float,
    height: float,
    color: Color,
    has_collision: bool = true,
    material_override: Material = null
) -> void:
    var node := StaticBody3D.new()
    node.position = position

    if has_collision:
        var collision := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = radius
        shape.height = height
        collision.shape = shape
        node.add_child(collision)

    var mesh_instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 48
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

func _spawn_ramp(
    position: Vector3,
    size: Vector3,
    pitch_degrees: float,
    color: Color,
    visible: bool = true,
    has_collision: bool = true,
    yaw_degrees: float = 0.0,
    roll_degrees: float = 0.0
) -> void:
    var node := StaticBody3D.new()
    node.position = position
    node.rotation_degrees.x = pitch_degrees
    node.rotation_degrees.y = yaw_degrees
    node.rotation_degrees.z = roll_degrees

    if has_collision:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        node.add_child(collision)

    if visible:
        var mesh_instance := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = size
        mesh_instance.mesh = mesh

        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 0.95
        material.metallic = 0.0
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        mesh_instance.material_override = material
        node.add_child(mesh_instance)

    geometry_root.add_child(node)
