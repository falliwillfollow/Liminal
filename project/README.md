# Liminal

A Godot 4 foundation for a first-person liminal-space walking simulator with puzzle-centric progression.

## Run
1. Install Godot 4.2+.
2. Open `project/project.godot`.
3. Run the main scene.

## Controls
- `WASD`: Move
- `Shift`: Sprint
- `Space`: Jump
- `E`: Interact
- `Esc`: Toggle mouse capture

## Folder Layout
- `project/scenes`: Scene graph roots and composition.
- `project/scripts`: Movement, atmosphere, puzzle framework, interactable base classes.
- `project/docs`: Architecture notes and extension guidance.

## Design Notes
- Geometry is generated in `LiminalLevel.gd` for fast shape iteration.
- Puzzle actors should inherit `Interactable.gd`.
- Global puzzle state should flow through `PuzzleController.gd`.
