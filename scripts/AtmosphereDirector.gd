extends Node
class_name AtmosphereDirector

@export var fog_density_base: float = 0.0015
@export var fog_density_peak: float = 0.003
@export var pulse_speed: float = 0.06

var _time: float = 0.0
var _world_environment: WorldEnvironment

func setup(world_environment: WorldEnvironment) -> void:
    _world_environment = world_environment

func _process(delta: float) -> void:
    if _world_environment == null:
        return

    _time += delta * pulse_speed
    var t := (sin(_time) + 1.0) * 0.5
    var env := _world_environment.environment
    if env:
        env.fog_density = lerp(fog_density_base, fog_density_peak, t)
