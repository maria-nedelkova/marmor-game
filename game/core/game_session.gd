## One attempt at one world: the board, the score, the queue, and the turn loop.
##
## Ported from the web version's `useGame.ts`, minus everything React-shaped.
## This holds no nodes and does no drawing — it reports what happened through
## signals and the view animates them. That split is what makes a whole game
## testable without a scene, and it is the same reason `engine.gd` is pure.
##
## ## A turn
##
## 1. The player moves a marble along a path of empty cells.
## 2. Lines through the destination clear and score. **The turn then ends with
##    no spawn** — that free turn is the single largest advantage the player
##    has, and `spawn_on_clear` in the final world is what takes it away.
## 3. Otherwise the queue spawns, and lines through the new marbles clear too.
## 4. A full board ends the attempt. Reaching the world's target wins it.
##
## ## What is NOT here
##
## No crash-recovery snapshot. The web version persists mid-run to survive iOS
## evicting a backgrounded tab; a native app gets told it is being suspended
## and can save then, so porting that design would carry over reasoning that
## does not hold here. PlayerProgress records the outcome, not the position.
class_name GameSession
extends RefCounted

signal marble_moved(path: Array[Vector2i], color: int)
signal cells_cleared(cells: Array[Vector2i], points: int)
signal marbles_spawned(cells: Array[Vector2i])
signal queue_changed(colors: Array[int])
signal score_changed(score: int)
signal finished(won: bool)

enum Phase { PLAYING, WON, LOST }

var world_index: int
var world: Dictionary
var board: Board
var score: int = 0
var phase: Phase = Phase.PLAYING
var next_queue: Array[int] = []
var charges: Dictionary = {}
var selected: Vector2i = Vector2i(-1, -1)


func _init(index: int) -> void:
	world_index = clampi(index, 0, Worlds.COUNT - 1)
	world = Worlds.get_world(world_index)
	board = Board.new()
	charges = Tools.grant_charges(Tools.no_charges(), world_index)
	_refill_queue()
	# The opening board is dealt without blocking — there are no lines to block
	# yet, and a "threat" on an empty board is meaningless.
	_place(int(world["start_count"]), true)


func target() -> int:
	return int(world["target"])


func has_selection() -> bool:
	return selected.x != -1


## Points for a clear, scaled by the world's multiplier. The multiplier is the
## only place the escalating target touches gameplay — see worlds.gd for why
## that leaves the level playing identically.
func score_for(cell_count: int) -> int:
	return MarmorEngine.score_for_clear(cell_count) * int(world["multiplier"])


## Taps a cell. Returns what the tap did, so the view knows whether to animate:
## "select", "deselect", "move", or "none".
func tap(cell: Vector2i) -> String:
	if phase != Phase.PLAYING or not Board.in_bounds(cell.x, cell.y):
		return "none"

	# Tapping an occupied cell always selects it, even with something already
	# selected. Requiring a deselect first means a misdirected tap costs two
	# more taps to undo, and there is nothing to protect against here.
	if not board.is_empty_at(cell.x, cell.y):
		if has_selection() and selected == cell:
			selected = Vector2i(-1, -1)
			return "deselect"
		selected = cell
		return "select"

	if not has_selection():
		return "none"

	var path := MarmorEngine.find_path(board, selected, cell)
	if path.is_empty():
		return "none"

	_commit_move(path)
	return "move"


func _commit_move(path: Array[Vector2i]) -> void:
	var from := path[0]
	var to := path[path.size() - 1]
	var color := board.at(from.x, from.y)

	board.clear_at(from.x, from.y)
	board.set_at_cell(to, color)
	selected = Vector2i(-1, -1)
	marble_moved.emit(path, color)

	var matched := MarmorEngine.find_lines_through(board, to)
	if matched.size() > 0:
		_clear(matched)
		# A clearing move ends the turn with no spawn — except in the final
		# world, where spawn_on_clear takes that free turn away.
		if not bool(world["spawn_on_clear"]):
			_check_finished()
			return

	_place(int(world["spawn_count"]), false)


func _clear(cells: Array[Vector2i]) -> void:
	for p in cells:
		board.clear_at(p.x, p.y)
	var points := score_for(cells.size())
	score += points
	cells_cleared.emit(cells, points)
	score_changed.emit(score)


## Places marbles and resolves anything they complete.
##
## `initial` suppresses two things: the blocking AI (no lines exist yet) and
## the queue refresh (the opening deal is not "what was coming next").
func _place(count: int, initial: bool) -> void:
	var color_count := int(world["colors"])
	var affinity := float(world["color_affinity"])
	var free := board.empty_cells()
	var to_place := mini(count, free.size())
	if to_place == 0:
		_check_finished()
		return

	var colors: Array[int] = []
	if initial:
		colors = MarmorEngine.weighted_random_colors(board, to_place, color_count, affinity)
	else:
		# Only the first `preview_count` were announced in Next up; anything
		# past that is rolled fresh, which is how later worlds spawn more
		# marbles than they show.
		for i in to_place:
			if i < next_queue.size():
				colors.append(next_queue[i])
			else:
				colors.append(MarmorEngine.weighted_random_color(board, color_count, affinity))

	# Each turn has a flat, per-world chance of the board hunting for the
	# player's near-complete lines instead of dropping anywhere empty.
	var can_block := not initial and MarmorEngine.rng.randf() < float(world["block_probability"])
	var assignment := MarmorEngine.assign_spawn_cells(
		board, colors, int(world["block_min_run_length"]), can_block, color_count
	)
	var cells: Array[Vector2i] = assignment["cells"]
	for i in cells.size():
		board.set_at_cell(cells[i], colors[i])

	if cells.size() > 0:
		marbles_spawned.emit(cells)
	if not initial:
		_refill_queue()

	# A spawned marble can complete a line too. Collected across all of them
	# first, so two spawns completing the same line score it once.
	var matched: Array[Vector2i] = []
	var seen := {}
	for cell in cells:
		for p in MarmorEngine.find_lines_through(board, cell):
			if not seen.has(p):
				seen[p] = true
				matched.append(p)
	if matched.size() > 0:
		_clear(matched)

	_check_finished()


func _refill_queue() -> void:
	next_queue = MarmorEngine.weighted_random_colors(
		board, int(world["preview_count"]), int(world["colors"]), float(world["color_affinity"])
	)
	queue_changed.emit(next_queue)


## Winning is checked before losing. A move that both reaches the target and
## fills the board is a win — the player met the King's score, and the board
## running out afterwards is a technicality.
func _check_finished() -> void:
	if phase != Phase.PLAYING:
		return
	if score >= target():
		phase = Phase.WON
		finished.emit(true)
		return
	if board.empty_cells().is_empty():
		phase = Phase.LOST
		finished.emit(false)


# --- tools -----------------------------------------------------------------


func can_use(tool_id: String) -> bool:
	if phase != Phase.PLAYING:
		return false
	var tool_def := Tools.find_tool(tool_id)
	if tool_def.is_empty() or not Tools.is_unlocked(tool_def, world_index):
		return false
	return Tools.has_charge(charges, tool_id)


## Spends a charge only when the tool actually did something — each board
## operation reports whether it changed anything, precisely so a no-op does not
## cost the player a charge.
func _spend(tool_id: String) -> void:
	charges = Tools.spend_charge(charges, tool_id)


## Tools that need no target. Returns true if one was used.
func use_tool(tool_id: String) -> bool:
	if not can_use(tool_id):
		return false

	match tool_id:
		Tools.REROLL:
			_refill_queue()
			_spend(tool_id)
			return true
		Tools.SHUFFLE:
			if not MarmorEngine.shuffle_board_colors(board):
				return false
			_spend(tool_id)
			# A shuffle can complete lines, and they belong to the player.
			_resolve_all_lines()
			return true
		_:
			return false


## Tools that need a board cell.
func use_tool_at(tool_id: String, cell: Vector2i, second: Vector2i = Vector2i(-1, -1)) -> bool:
	if not can_use(tool_id):
		return false

	match tool_id:
		Tools.HAMMER:
			if not MarmorEngine.smash_marble(board, cell):
				return false
		Tools.BOMB:
			if MarmorEngine.bomb_at(board, cell) == 0:
				return false
		Tools.SWAP:
			if not MarmorEngine.swap_marble_colors(board, cell, second):
				return false
		_:
			return false

	_spend(tool_id)
	_resolve_all_lines()
	return true


## Sweeps the whole board for completed lines. Needed after a tool, which can
## complete a line anywhere rather than at a known cell.
func _resolve_all_lines() -> void:
	var matched: Array[Vector2i] = []
	var seen := {}
	for p in board.occupied_cells():
		for q in MarmorEngine.find_lines_through(board, p):
			if not seen.has(q):
				seen[q] = true
				matched.append(q)
	if matched.size() > 0:
		_clear(matched)
	_check_finished()
