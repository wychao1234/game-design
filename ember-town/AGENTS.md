# Ember Town project instructions

- Build the agreed single-player desktop prototype with Godot 4.5.2 and GDScript. Keep Forward+ as the reference renderer.
- Approved direction now supersedes mine-only scope: eastern-fantasy pixel characters in 3D Linchuan town, ferry and boss arenas, with the approved close oblique camera and warm-lantern/cool-rain palette.
- Use the existing native producer/design/programming/art/QA/build agent split. Claude Code Game Studios was explicitly cancelled by the user; do not introduce its framework or hooks.
- Apply Ponytail full principles during coding: read the affected flow and callers first; make the smallest complete change; reuse Godot features and existing project helpers; do not add speculative abstractions or dependencies. Preserve validation, accessibility and data-loss protection.
- Ponytail source: https://github.com/DietrichGebert/ponytail/blob/main/skills/ponytail/SKILL.md . This is a project coding convention, not a claim that a Ponytail plugin or Claude Code client is installed.
- Keep game.gd and room.gd ownership explicit. QA should report a reproducible defect before a developer changes shared files.
- Run meaningful checks for changed combat, collision and persistence rules. Include ordinary success behavior as well as the failing edge case.
- Use tests/run_qa.py with the pinned engine. Headless checks, rendered frames, exported packages and Windows target execution are distinct evidence.
- Preserve source hashes and known limitations in docs/QA.md and package build metadata. Never report a Windows target run or user-GPU frame rate without testing it.
- Current milestone: separate adventure.tscn with town/select/ferry/boss/results/equipment/save loop, four preview characters, three selected, one human on field, four skills each, shared dodge/awakening. This is a representative preview, not the whole first chapter or a 30-hour game. Preserve legacy main.tscn and game.gd and the old ember_save.json.
- Team ownership: root/integration owns adventure.gd and adventure_hud.gd; combat owns adventure_combat.gd; progress owns adventure_progress.gd; world owns waterfront.gd and shaders; art owns assets/characters; QA owns new preview tests; build owns tools/build.py and release docs.
- Save a durable checkpoint ZIP after restoring each major module and before long visual iteration; do not leave the only copy in scratch.
