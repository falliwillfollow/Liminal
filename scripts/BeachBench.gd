extends StaticBody3D
class_name BeachBench

signal sat_down(bench: BeachBench, actor: Node)

@export var seat_offset := Vector3(0.0, 0.86, 0.26)
@export var look_offset := Vector3(0.0, 1.05, -60.0)

func interact(actor: Node) -> void:
    if actor == null:
        return
    if not actor.has_method("focus_viewpoint"):
        return

    var seat_position := global_position + global_transform.basis * seat_offset
    var look_target := global_position + global_transform.basis * look_offset
    actor.focus_viewpoint(seat_position, look_target)
    sat_down.emit(self, actor)
