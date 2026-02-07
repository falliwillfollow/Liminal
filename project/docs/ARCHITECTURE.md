# Liminal Engine Architecture (Godot 4)

## Vision
A first-person walking simulator with retro-era visuals, oppressive atmosphere, and puzzle-first progression.

## Core Loop
1. Explore ambiguous liminal spaces.
2. Read environmental cues.
3. Solve spatial/audio/light-based puzzles.
4. Unlock deeper layers of the space.

## Current Foundation
- `scenes/Main.tscn`: Root scene, world environment and main level composition.
- `scenes/Player.tscn`: Character body + camera look + interaction ray.
- `scripts/PlayerController.gd`: FPS movement, mouse look, and interaction dispatch.
- `scripts/LiminalLevel.gd`: Programmatic blockout generator for rapid iteration.
- `scripts/PuzzleController.gd`: Puzzle lifecycle + state signals for decoupled systems.
- `scripts/AtmosphereDirector.gd`: Time-based ambient modulation hooks.

## Puzzle Integration Pattern
- Create puzzle nodes that inherit from `Interactable` and implement `interact(actor)`.
- Register puzzle IDs with `PuzzleController` when starting/solving/failing.
- Drive environmental changes via signals (`doors`, `lights`, `sound`, `fog`, `geometry`).

## Atmosphere Design Hooks
- Lighting flicker component for unstable visual rhythm.
- Global fog and subdued ambient base for depth ambiguity.
- Nearest-neighbor filtering and rough materials for retro look.
- Keep geometry simple and exaggerated to preserve uncanny scale.

## Suggested Next Steps
- Add lo-fi post-process shader (dither + slight color banding).
- Add diegetic audio zones and directional hum/drone loops.
- Build one vertical-slice puzzle from hint discovery to unlock event.
- Add save/checkpoint and puzzle state persistence.
