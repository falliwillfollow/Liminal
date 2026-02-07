extends Node3D

const ROAD_LENGTH := 220.0
const ROAD_WIDTH := 8.0
const SIDEWALK_WIDTH := 2.5
const LOT_DEPTH := 22.0
const BLOCK_STEP := 22.0
const HOUSE_COUNT_PER_SIDE := 10
const TERMINUS_Z := ROAD_LENGTH * 0.5 - 10.0
const DOOR_SCRIPT := preload("res://scripts/Door.gd")

@onready var geometry_root: Node3D = $GeometryRoot

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.seed = 24031998
    _build_town()
    _add_street_lights()

func _build_town() -> void:
    _spawn_ground()
    _spawn_road()
    _spawn_sidewalks()
    _spawn_houses()
    _spawn_terminus_and_institution()

func _spawn_ground() -> void:
    _spawn_box(Vector3(0, -0.55, 0), Vector3(220, 1.1, ROAD_LENGTH + 30.0), Color(0.17, 0.2, 0.16))

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
        _spawn_lot(left_lot_x, z, true)
        _spawn_lot(right_lot_x, z, false)

func _spawn_lot(lot_center_x: float, lot_center_z: float, face_right: bool) -> void:
    _spawn_box(Vector3(lot_center_x, 0.03, lot_center_z), Vector3(LOT_DEPTH, 0.06, BLOCK_STEP - 1.5), Color(0.24, 0.28, 0.22), false)

    var toward_road := 1.0 if face_right else -1.0
    var house_x := lot_center_x + (toward_road * _rng.randf_range(0.4, 2.2))
    var house_z := lot_center_z + _rng.randf_range(-2.4, 2.4)

    var base_color := Color(
        _rng.randf_range(0.38, 0.66),
        _rng.randf_range(0.37, 0.63),
        _rng.randf_range(0.33, 0.58)
    )
    var trim_color := base_color.lightened(0.16)
    var roof_color := base_color.darkened(0.36)

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

    # Central island feature
    _spawn_cylinder(Vector3(0, 0.55, TERMINUS_Z), 4.6, 1.1, Color(0.32, 0.32, 0.3))
    _spawn_box(Vector3(0, 2.2, TERMINUS_Z), Vector3(0.55, 3.3, 0.55), Color(0.24, 0.24, 0.24))

    # Institution sits beyond the terminus
    var front_z := TERMINUS_Z + terminus_radius + 5.0
    _spawn_asylum(front_z)

    # Perimeter fence and gate line
    var fence_z := TERMINUS_Z + terminus_radius + 1.6
    for x in range(-20, 21, 2):
        if abs(x) <= 4:
            continue
        _spawn_box(Vector3(float(x), 1.1, fence_z), Vector3(0.18, 2.2, 0.18), Color(0.18, 0.18, 0.2))
    _spawn_box(Vector3(-11.0, 1.65, fence_z), Vector3(18.0, 0.12, 0.12), Color(0.18, 0.18, 0.2))
    _spawn_box(Vector3(11.0, 1.65, fence_z), Vector3(18.0, 0.12, 0.12), Color(0.18, 0.18, 0.2))

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

    # Main shell perimeter walls (hollow interior). Side walls include open passages to stair towers.
    var stair_passage_d := 2.6
    var side_segment_d := (building_d - stair_passage_d) * 0.5
    var left_wall_x := -building_w * 0.5 + wall_t * 0.5
    var right_wall_x := building_w * 0.5 - wall_t * 0.5
    var front_seg_center_z := front_z + side_segment_d * 0.5
    var back_seg_center_z := front_z + building_d - side_segment_d * 0.5
    _spawn_box(Vector3(left_wall_x, total_h * 0.5, front_seg_center_z), Vector3(wall_t, total_h, side_segment_d), facade_color)
    _spawn_box(Vector3(left_wall_x, total_h * 0.5, back_seg_center_z), Vector3(wall_t, total_h, side_segment_d), facade_color)
    _spawn_box(Vector3(right_wall_x, total_h * 0.5, front_seg_center_z), Vector3(wall_t, total_h, side_segment_d), facade_color)
    _spawn_box(Vector3(right_wall_x, total_h * 0.5, back_seg_center_z), Vector3(wall_t, total_h, side_segment_d), facade_color)
    var doorway_w := 4.8
    var doorway_h := 3.4
    var front_segment_w := (building_w - doorway_w) * 0.5
    _spawn_box(
        Vector3(-doorway_w * 0.5 - front_segment_w * 0.5, total_h * 0.5, front_z + wall_t * 0.5),
        Vector3(front_segment_w, total_h, wall_t),
        facade_color
    )
    _spawn_box(
        Vector3(doorway_w * 0.5 + front_segment_w * 0.5, total_h * 0.5, front_z + wall_t * 0.5),
        Vector3(front_segment_w, total_h, wall_t),
        facade_color
    )
    _spawn_box(
        Vector3(0, doorway_h + (total_h - doorway_h) * 0.5, front_z + wall_t * 0.5),
        Vector3(doorway_w, total_h - doorway_h, wall_t),
        facade_color
    )
    _spawn_box(Vector3(0, total_h * 0.5, front_z + building_d - wall_t * 0.5), Vector3(building_w, total_h, wall_t), facade_color)
    _spawn_box(Vector3(0, total_h + 0.35, center_z), Vector3(building_w + 1.2, 0.7, building_d + 1.2), trim_color)

    # Front doorway frame + large two-panel hinged door.
    _spawn_box(Vector3(-2.85, 1.7, front_z + 0.75), Vector3(0.6, 3.4, 0.9), Color(0.48, 0.48, 0.46))
    _spawn_box(Vector3(2.85, 1.7, front_z + 0.75), Vector3(0.6, 3.4, 0.9), Color(0.48, 0.48, 0.46))
    _spawn_box(Vector3(0, 3.72, front_z + 0.75), Vector3(6.3, 0.64, 0.9), Color(0.48, 0.48, 0.46))
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
        _spawn_box(Vector3(0, y_floor + 0.08, center_z), Vector3(building_w - 0.9, 0.16, building_d - 0.9), Color(0.34, 0.34, 0.33))

        # Exactly 12 rooms per level: 6 on each side of the corridor
        _spawn_level_rooms(front_z, building_w, building_d, wall_t, y_floor, floor_h, level)

        # Bridge floor between corridor edge and each stair tower opening.
        var side_values: Array[float] = [-1.0, 1.0]
        for side in side_values:
            var bridge_x := side * (building_w * 0.5 + 1.55)
            _spawn_box(
                Vector3(bridge_x, y_floor + 0.06, center_z),
                Vector3(4.0, 0.24, 4.2),
                Color(0.34, 0.34, 0.33)
            )

    # Flat entry approach (stairs removed): prevents trapping/drop on exit.
    _spawn_box(
        Vector3(0, 0.08, front_z - 1.8),
        Vector3(12.8, 0.16, 4.4),
        Color(0.5, 0.5, 0.47)
    )

    # End stair towers: one at each building end for vertical circulation
    _spawn_side_stair_tower(-1.0, front_z, building_w, building_d, floor_h, levels)
    _spawn_side_stair_tower(1.0, front_z, building_w, building_d, floor_h, levels)

    # Imposing central raised mass
    _spawn_box(Vector3(0, total_h + 3.3, front_z + 10.5), Vector3(14.0, 6.6, 9.2), Color(0.51, 0.51, 0.49))
    _spawn_box(Vector3(0, total_h + 6.9, front_z + 10.5), Vector3(14.8, 0.8, 10.0), Color(0.23, 0.23, 0.25))

func _spawn_level_rooms(front_z: float, building_w: float, building_d: float, wall_t: float, y_floor: float, floor_h: float, level: int) -> void:
    var corridor_w := 4.2
    var center_z := front_z + building_d * 0.5
    var row_depth := (building_d - corridor_w - wall_t * 2.0) * 0.5
    var room_count_side := 6
    var usable_w := building_w - wall_t * 2.0
    var room_w := usable_w / float(room_count_side)
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
                _spawn_box(Vector3(room_center_x, top_y, back_z), Vector3(room_w - 0.08, wall_h, wall_t), Color(0.58, 0.58, 0.56))

            # Corridor-side wall split into two pieces with a doorway gap
            var door_w := 1.25
            var seg_w := (room_w - door_w) * 0.5
            var left_x := room_center_x - (door_w * 0.5 + seg_w * 0.5)
            var right_x := room_center_x + (door_w * 0.5 + seg_w * 0.5)
            if not is_entry_lobby_room:
                _spawn_box(Vector3(left_x, top_y, corridor_edge_z), Vector3(seg_w, wall_h, wall_t), Color(0.58, 0.58, 0.56))
                _spawn_box(Vector3(right_x, top_y, corridor_edge_z), Vector3(seg_w, wall_h, wall_t), Color(0.58, 0.58, 0.56))

            # Interior divider between rooms (skip final room)
            if i < room_count_side - 1:
                var div_x := room_center_x + room_w * 0.5 - wall_t * 0.5
                var is_lobby_center_divider := is_front_ground and i == 2
                if not is_lobby_center_divider:
                    _spawn_box(Vector3(div_x, top_y, row_center_z), Vector3(wall_t, wall_h, row_depth), Color(0.56, 0.56, 0.54))

            # Room marker panel to reinforce 12-room-per-level layout visually
            var marker_tint := 0.09 + 0.03 * float(level)
            _spawn_box(
                Vector3(room_center_x, y_floor + 1.35, row_center_z),
                Vector3(0.9, 0.6, 0.08),
                Color(0.22 + marker_tint, 0.22 + marker_tint, 0.24 + marker_tint)
            )

func _spawn_side_stair_tower(side: float, front_z: float, building_w: float, building_d: float, floor_h: float, levels: int) -> void:
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
    _spawn_box(Vector3(outer_wall_x, wall_h_total * 0.5, center_z), Vector3(wt, wall_h_total, tower_d), tower_color)
    _spawn_box(Vector3(inner_wall_x, wall_h_total * 0.5, front_seg_z), Vector3(wt, wall_h_total, wall_seg_d), tower_color)
    _spawn_box(Vector3(inner_wall_x, wall_h_total * 0.5, back_seg_z), Vector3(wt, wall_h_total, wall_seg_d), tower_color)
    _spawn_box(Vector3(tower_x, wall_h_total * 0.5, center_z - tower_d * 0.5 + wt * 0.5), Vector3(tower_w, wall_h_total, wt), tower_color)
    _spawn_box(Vector3(tower_x, wall_h_total * 0.5, center_z + tower_d * 0.5 - wt * 0.5), Vector3(tower_w, wall_h_total, wt), tower_color)
    _spawn_box(Vector3(tower_x, wall_h_total + 0.2, center_z), Vector3(tower_w + 0.4, 0.4, tower_d + 0.4), Color(0.24, 0.24, 0.26))

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
    _spawn_box(Vector3(tower_x, floor_thickness * 0.5, center_z), Vector3(tower_floor_w, floor_thickness, tower_floor_d), floor_color)

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
        floor_color
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
        floor_color
    )

    # Explicit switchback/arrival landings at level boundaries.
    var landing_w: float = absf(lane_outer_x - lane_inner_x) + 2.6
    _spawn_box(
        Vector3((lane_outer_x + lane_inner_x) * 0.5, floor_h + floor_thickness * 0.5, north_z + 1.1),
        Vector3(landing_w, floor_thickness, 2.2),
        floor_color
    )
    _spawn_box(
        Vector3((lane_outer_x + lane_inner_x) * 0.5, floor_h * 2.0 + floor_thickness * 0.5, south_z - 1.1),
        Vector3(landing_w, floor_thickness, 2.2),
        floor_color
    )

    # First flight: level 0 south -> level 1 north (outer lane).
    _spawn_stair_flight(lane_outer_x, 0.0, south_z, stair_w, tread, riser, step_count, 1.0)
    _spawn_ramp(
        Vector3(lane_outer_x, floor_h * 0.5, south_z + run_len * 0.5),
        Vector3(ramp_w, 0.48, run_len + 0.12),
        -pitch,
        Color(0, 0, 0),
        false,
        true
    )

    # Second flight: level 1 north -> level 2 south (inner lane), offset from the first.
    _spawn_stair_flight(lane_inner_x, floor_h, north_z, stair_w, tread, riser, step_count, -1.0)
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
    dir: float
) -> void:
    for i in range(step_count):
        var y := y_base + riser * 0.5 + float(i) * riser
        var z := z_start + dir * (float(i) * tread + tread * 0.5)
        _spawn_box(Vector3(x, y, z), Vector3(width, riser, tread + 0.03), Color(0.43, 0.43, 0.42), false)

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
    color: Color
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
        _spawn_box(Vector3(center_x, y, center_z), Vector3(total_w, thickness, total_d), color)
        return

    var left_w: float = hx0 - x_min
    if left_w > 0.14:
        _spawn_box(Vector3(x_min + left_w * 0.5, y, center_z), Vector3(left_w, thickness, total_d), color)

    var right_w: float = x_max - hx1
    if right_w > 0.14:
        _spawn_box(Vector3(hx1 + right_w * 0.5, y, center_z), Vector3(right_w, thickness, total_d), color)

    var center_w: float = hx1 - hx0
    var front_d: float = hz0 - z_min
    if center_w > 0.14 and front_d > 0.14:
        _spawn_box(Vector3((hx0 + hx1) * 0.5, y, z_min + front_d * 0.5), Vector3(center_w, thickness, front_d), color)

    var back_d: float = z_max - hz1
    if center_w > 0.14 and back_d > 0.14:
        _spawn_box(Vector3((hx0 + hx1) * 0.5, y, hz1 + back_d * 0.5), Vector3(center_w, thickness, back_d), color)

func _spawn_interactable_door(
    position: Vector3,
    size: Vector3,
    color: Color,
    open_direction: float,
    hinge_offset_x: float
) -> void:
    var door := StaticBody3D.new()
    door.position = position
    door.set_script(DOOR_SCRIPT)
    door.set("open_direction", open_direction)
    door.set("open_angle_degrees", 108.0)
    door.set("open_speed", 7.0)

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

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    material.metallic = 0.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mesh_instance.material_override = material

    door.add_child(mesh_instance)
    geometry_root.add_child(door)

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

func _spawn_box(position: Vector3, size: Vector3, color: Color, has_collision: bool = true) -> void:
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

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.95
    material.metallic = 0.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mesh_instance.material_override = material

    node.add_child(mesh_instance)
    geometry_root.add_child(node)

func _spawn_cylinder(position: Vector3, radius: float, height: float, color: Color, has_collision: bool = true) -> void:
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
    has_collision: bool = true
) -> void:
    var node := StaticBody3D.new()
    node.position = position
    node.rotation_degrees.x = pitch_degrees

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
