# Project Working Rules

- Keep replies short, direct, and focused on the requested task. Avoid long explanations and unnecessary questions.
- Make the requested change directly when the requirements are clear; ask only when an essential detail is missing.
- Do not generate images or other visual assets unless the user explicitly requests them.
- Inspect the current files and project structure before editing. Do not rely on stale branch or commit information.
- Change only files needed for the requested task. Do not delete, rename, reformat, or rewrite unrelated files.
- Preserve existing gameplay systems, controls, scenes, assets, and data unless the user explicitly asks to change them.
- For gameplay changes, reuse existing signals, animations, damage, health, drops, and interaction pipelines wherever possible.
- Avoid broad refactors. Keep changes small and compatible with the current branch.
- Never claim a feature is tested unless it was actually run and verified in the target environment. State clearly when Godot/runtime testing was not possible.
- Do not commit or push unless the user has asked for implementation in the project or otherwise clearly authorized it.
- After changes, report only the files changed, the commit (if any), and any important testing limitation.


## Auto-chop behavior and debugging context

- Tree auto-chop is implemented in `scripts/characters/player.gd`; preserve the existing tree `hit()` pipeline and tree-specific health, fall, stump, and drop logic.
- Expected behavior: with the axe selected, one click on a chop-able tree makes the player approach it, stop at a safe interaction distance, and repeatedly swing until the tree is felled. Stumps are not part of the auto-chop target.
- Auto-chop state is tracked by `auto_chop_target`, `auto_chop_active`, and `auto_chop_swing_pending`. Keep target validation, cancellation on manual movement/tool changes, and invalid-target handling intact.
- Do not use animation-finished signals as the only mechanism for scheduling repeated swings. AnimationTree callbacks may fail to release the loop in some runtime states; use a bounded swing cooldown as a recovery path and keep it synchronized with the axe animation duration.
- Do not change `current_tool` as part of auto-chop. The axe animation state is separate from the selected tool value; only the user's tool-switch input may change the selected tool.
- When changing player movement/animation locks, ensure auto-chop processing still advances and can recover from a missed animation callback without freezing the player.
- Test in Godot: click a mature tree from a distance, confirm the player approaches, swings repeatedly, damages the same tree, stops after it falls, and does not change the selected tool. Also test manual movement and switching tools to confirm auto-chop cancels cleanly.
