extends Node
class_name PuzzleController

signal puzzle_started(id: String)
signal puzzle_solved(id: String)
signal puzzle_failed(id: String)

var states: Dictionary = {}

func start_puzzle(id: String) -> void:
    states[id] = "started"
    puzzle_started.emit(id)

func solve_puzzle(id: String) -> void:
    states[id] = "solved"
    puzzle_solved.emit(id)

func fail_puzzle(id: String) -> void:
    states[id] = "failed"
    puzzle_failed.emit(id)
