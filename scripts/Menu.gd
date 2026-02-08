extends Control

const GAME_SCENE := "res://scenes/Main.tscn"

@onready var start_button: Button = $CenterContainer/Panel/VBoxContainer/StartButton
@onready var exit_button: Button = $CenterContainer/Panel/VBoxContainer/ExitButton

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    start_button.pressed.connect(_on_start_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    start_button.grab_focus()

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file(GAME_SCENE)

func _on_exit_pressed() -> void:
    get_tree().quit()
