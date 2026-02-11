extends StaticBody3D
class_name BlackCube

signal activated(cube: BlackCube)

var _is_activated := false

func interact(_actor: Node) -> void:
    if _is_activated:
        return
    _is_activated = true
    activated.emit(self)
