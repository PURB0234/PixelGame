# Project Working Rules

- **Always read this file (`skills.md`) first before starting any work on this project**, so the context and rules below are applied.
- **After every fix or change: update `skills.md` (rules/context/lessons learned), commit, and push** so the owner can just `git pull`. This is explicitly authorized by the owner and overrides the older "do not commit or push" rule below.
- Keep replies short, direct, and focused on the requested task. Avoid long explanations and unnecessary questions.
- Make the requested change directly when the requirements are clear; ask only when an essential detail is missing.
- Do not generate images or other visual assets unless the user explicitly requests them.
- Inspect the current files and project structure before editing. Do not rely on stale branch or commit information.
- Change only files needed for the requested task. Do not delete, rename, reformat, or rewrite unrelated files.
- Preserve existing gameplay systems, controls, scenes, assets, and data unless the user explicitly asks to change them.
- For gameplay changes, reuse existing signals, animations, damage, health, drops, and interaction pipelines wherever possible.
- Avoid broad refactors. Keep changes small and compatible with the current branch.
- Never claim a feature is tested unless it was actually run and verified in the target environment. State clearly when Godot/runtime testing was not possible.
- Push workflow: the sandbox has no GitHub credentials by default. The owner provides a short-lived fine-grained token (only repo `PixelGame`, Contents: Read and write). Push with a one-off header, never store the token (no remote URL, no git config, no files): `git -c http.extraheader="Authorization: Basic $(printf 'x-access-token:%s' "$TOKEN" | base64 -w0)" push origin HEAD:master`. Always verify with `git ls-remote origin master`. Without a token, export `git format-patch -1 HEAD --stdout` and tell the owner to run `git am <file>.patch && git push`. Remind the owner to revoke the token after use.
- Commit and push after every completed change (authorized by the owner). Commit only the files needed for the task; never commit `.tmp` files or Godot cache.
- After changes, report only the files changed, the commit (if any), and any important testing limitation.


## Auto-chop behavior and debugging context

- Tree auto-chop is implemented in `scripts/characters/player.gd`; preserve the existing tree `hit()` pipeline and tree-specific health, fall, stump, and drop logic.
- Expected behavior: with the axe selected, one click on a chop-able tree makes the player approach it, stop at a safe interaction distance, and repeatedly swing until the tree is felled. Stumps are not part of the auto-chop target.
- Auto-chop state is tracked by `auto_chop_target`, `auto_chop_active`, and `auto_chop_swing_pending`. Keep target validation, cancellation on manual movement/tool changes, and invalid-target handling intact.
- Do not use animation-finished signals as the only mechanism for scheduling repeated swings. AnimationTree callbacks may fail to release the loop in some runtime states; use a bounded swing cooldown as a recovery path and keep it synchronized with the axe animation duration.
- Do not change `current_tool` as part of auto-chop. The axe animation state is separate from the selected tool value; only the user's tool-switch input may change the selected tool.
- When changing player movement/animation locks, ensure auto-chop processing still advances and can recover from a missed animation callback without freezing the player.
- Test in Godot: click a mature tree from a distance, confirm the player approaches, swings repeatedly, damages the same tree, stops after it falls, and does not change the selected tool. Also test manual movement and switching tools to confirm auto-chop cancels cleanly.

- Parser compatibility: `_process_auto_chop()` may be called directly when auto-chop starts and deferred with an explicit delta after an animation callback. Keep its `delta` parameter optional (default `0.0`) or pass an argument at every call site; otherwise Godot reports `Too few arguments` during parsing.

## Auto-chop fix log (root cause + rules)

- Root cause of "player walks to the tree but never chops": the arrival check (`distance <= 19`) was tighter than where the player actually stops. The approach target was 17px from the tree and `move()` accepts arrival within 4px, so the player stopped at ~20px, was re-targeted every frame, and never swung. Keep `AUTO_CHOP_STAND_DISTANCE + 4 < AUTO_CHOP_RANGE < 22` (22 is the axe hit range in `level.gd` `_on_player_tool_use`). Current values: stand 14, range 20.
- Facing direction used for auto-chop must be snapped to 4 directions via `_to_cardinal()`. A diagonal blend position plays two axe animations at once, so `tool_use_emit` fires twice per swing (double damage).
- Stuck recovery: if the player makes no progress while approaching for `AUTO_CHOP_STUCK_TIMEOUT` (1.0s), auto-chop cancels instead of freezing. Keep this when changing movement/collision.

## Headless runtime testing (works in this environment)

- Godot 4.7.2 can be downloaded from `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`.
- Run `godot --headless --import --path .` once, then run a `SceneTree` script with `godot --headless --path . -s test.gd` that instantiates `res://scenes/levels/level.tscn`, gets `%Player`, calls `_begin_auto_chop(tree)` and steps `await physics_frame`, checking `tree.tree_health`. Keep test scripts outside the repo (e.g. `/tmp`).
- Verified 2026-11-14 headless: auto-chop fells a tree from 8 different approach positions, keeps `current_tool`, cancels on tool switch, and cancels when blocked. Real keyboard/mouse/gamepad play was not tested.
