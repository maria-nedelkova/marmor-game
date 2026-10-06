## The pure game engine: pathfinding, line detection, scoring, spawn placement.
##
## Ported from the web version's `src/game/engine.ts`, which is the source of
## truth (see PLAN.md section 2 — the Swift package is notes, not source).
## No scene code, no nodes, no rendering. Everything here is a transform over
## a Board, so it is testable without a running game.
##
## Named MarmorEngine rather than Engine because `Engine` is a Godot built-in
## singleton; declaring `class_name Engine` would shadow it project-wide.
##
## ## Randomness
##
## `MarmorEngine.rng` is a static RandomNumberGenerator, swapped or seeded by
## tests. The web version wraps its PRNG in a mutable object for the same
## reason, though for a different underlying problem: there, browser privacy
## extensions shim `Math.random` to return degenerate values, which silently
## turns a spawn picker into "always index 0". Godot has no global to shim, so
## this exists purely for deterministic tests.
class_name MarmorEngine


## Additive smoothing: every colour's weight starts here before its on-board
## count is added, so this alone sets the floor probability for a colour that
## is not on the board at all.
##
## It was 1, which is far too low once the board fills. On a realistic
## 47-marble board with 8 colours that floor is 1/55 — about 1.8% per spawn,
## or an expected 18 turns before an absent colour appears. Observed in play:
## one colour never appeared across a whole round, and the 8th colour
## introduced in round 3 stayed at the single marble it started with, because
## a colour that falls behind has no way back. At 3 the floor is ~4.2%, about
## 8 turns, which keeps the palette moving without flattening the clustering
## that makes lines buildable in the first place.
const COLOR_SMOOTHING := 3

## Orthogonal steps, for travel.
const STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

## The four line axes: horizontal, vertical, and both diagonals. Only one
## direction each — both are walked from the origin cell.
const LINE_AXES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1),
]

static var rng := RandomNumberGenerator.new()


# --- colours ---------------------------------------------------------------


static func random_color(color_count: int = Rules.COLORS) -> int:
	return rng.randi_range(0, color_count - 1)


static func random_colors(n: int, color_count: int = Rules.COLORS) -> Array[int]:
	var out: Array[int] = []
	for _i in n:
		out.append(random_color(color_count))
	return out


## Picks a colour weighted toward colours already on the board — the more of a
## colour present, the likelier it spawns again, which makes lines easier to
## complete (and to run into by accident). COLOR_SMOOTHING keeps every colour
## reachable even when absent.
##
## `affinity` scales how much the on-board bias counts: 1 is the classic
## helpful clustering, 0 flattens it to uniform. Late worlds turn it down to
## make runs stall without changing anything the player can see.
static func weighted_random_color(board: Board, color_count: int = Rules.COLORS, affinity: float = 1.0) -> int:
	var counts := board.color_counts(color_count)
	var weights := PackedFloat64Array()
	weights.resize(color_count)
	var total := 0.0
	for i in color_count:
		var w := counts[i] * affinity + COLOR_SMOOTHING
		weights[i] = w
		total += w

	var roll := rng.randf() * total
	for i in color_count:
		roll -= weights[i]
		if roll < 0.0:
			return i
	# Floating-point drift only; the loop above covers the distribution.
	return color_count - 1


static func weighted_random_colors(
	board: Board, n: int, color_count: int = Rules.COLORS, affinity: float = 1.0
) -> Array[int]:
	var out: Array[int] = []
	for _i in n:
		out.append(weighted_random_color(board, color_count, affinity))
	return out


# --- travel ----------------------------------------------------------------


## BFS shortest path between two cells through empty cells only, 4-directional.
## Includes both ends.
##
## Returns an EMPTY array when unreachable, where the web version returns null.
## That is unambiguous rather than lossy: a real path always contains at least
## its start, so an empty result cannot be confused with a found path.
static func find_path(board: Board, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not Board.in_bounds(from.x, from.y) or not Board.in_bounds(to.x, to.y):
		return none
	if not board.is_empty_at(to.x, to.y):
		return none

	var size := Rules.SIZE
	var visited := PackedByteArray()
	visited.resize(size * size)
	visited.fill(0)
	# -1 means "no predecessor"; the start cell keeps it.
	var prev := PackedInt32Array()
	prev.resize(size * size)
	prev.fill(-1)

	var queue: Array[Vector2i] = [from]
	visited[from.x * size + from.y] = 1

	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == to:
			break
		for step in STEPS:
			var nr := cur.x + step.x
			var nc := cur.y + step.y
			if not Board.in_bounds(nr, nc):
				continue
			var idx := nr * size + nc
			if visited[idx] == 1:
				continue
			if not board.is_empty_at(nr, nc):
				continue
			visited[idx] = 1
			prev[idx] = cur.x * size + cur.y
			queue.append(Board.cell(nr, nc))

	if visited[to.x * size + to.y] == 0:
		return none

	var path: Array[Vector2i] = []
	var at := to.x * size + to.y
	while at != -1:
		path.push_front(Board.cell(at / size, at % size))
		at = prev[at]
	return path


## Every empty cell reachable from `from` via 4-directional travel through
## empty cells. Used to preview legal destinations. Excludes `from` itself,
## matching the web version.
static func reachable_from(board: Board, from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not Board.in_bounds(from.x, from.y):
		return out

	var size := Rules.SIZE
	var visited := PackedByteArray()
	visited.resize(size * size)
	visited.fill(0)
	visited[from.x * size + from.y] = 1

	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for step in STEPS:
			var nr := cur.x + step.x
			var nc := cur.y + step.y
			if not Board.in_bounds(nr, nc):
				continue
			var idx := nr * size + nc
			if visited[idx] == 1:
				continue
			if not board.is_empty_at(nr, nc):
				continue
			visited[idx] = 1
			var c := Board.cell(nr, nc)
			out.append(c)
			queue.append(c)
	return out


# --- lines -----------------------------------------------------------------


## The cells forming a line of at least LINE_MIN through `p`, across all four
## axes, unioned. Empty if none.
static func find_lines_through(board: Board, p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var color := board.at(p.x, p.y)
	if color == Board.EMPTY:
		return out

	# Vector2i is hashable, so a Dictionary dedupes the union directly. The
	# web version keys a Map by "r,c" strings because its Cell is a plain
	# object and two equal cells are different keys.
	var seen := {}

	for axis in LINE_AXES:
		var line: Array[Vector2i] = [p]
		var nr := p.x + axis.x
		var nc := p.y + axis.y
		while Board.in_bounds(nr, nc) and board.at(nr, nc) == color:
			line.append(Board.cell(nr, nc))
			nr += axis.x
			nc += axis.y
		nr = p.x - axis.x
		nc = p.y - axis.y
		while Board.in_bounds(nr, nc) and board.at(nr, nc) == color:
			line.push_front(Board.cell(nr, nc))
			nr -= axis.x
			nc -= axis.y
		if line.size() >= Rules.LINE_MIN:
			for c in line:
				if not seen.has(c):
					seen[c] = true
					out.append(c)
	return out


## The longest same-colour run that would pass through an empty cell if it were
## filled with `color` — "how long a line would this complete". Used to spot
## near-complete lines worth defending against.
static func longest_run_through(board: Board, p: Vector2i, color: int) -> int:
	var best := 1
	for axis in LINE_AXES:
		var length := 1
		var nr := p.x + axis.x
		var nc := p.y + axis.y
		while Board.in_bounds(nr, nc) and board.at(nr, nc) == color:
			length += 1
			nr += axis.x
			nc += axis.y
		nr = p.x - axis.x
		nc = p.y - axis.y
		while Board.in_bounds(nr, nc) and board.at(nr, nc) == color:
			length += 1
			nr -= axis.x
			nc -= axis.y
		if length > best:
			best = length
	return best


## Every empty cell that, filled with some colour, would extend a run to at
## least `min_length`. Most urgent first. This is what the spawner uses to find
## the player's in-progress lines worth blocking.
##
## Each entry is {cell: Vector2i, color: int, length: int}.
##
## **The sort carries a total order, and that is load-bearing.** The web
## version sorts on `b.length - a.length` alone and leans on JavaScript's sort
## being stable, so equal-length threats keep their row-major scan order.
## GDScript's `sort_custom` is NOT stable, so without the tie-breaks below,
## which line the spawner blocks would vary between runs on the same board —
## nondeterminism that would be very hard to trace back to here.
static func find_top_threats(
	board: Board, min_length: int = 3, color_count: int = Rules.COLORS
) -> Array[Dictionary]:
	var threats: Array[Dictionary] = []
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			if not board.is_empty_at(r, c):
				continue
			for color in color_count:
				var length := longest_run_through(board, Board.cell(r, c), color)
				if length >= min_length:
					threats.append({"cell": Board.cell(r, c), "color": color, "length": length})

	threats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["length"] != b["length"]:
			return a["length"] > b["length"]
		if a["cell"].x != b["cell"].x:
			return a["cell"].x < b["cell"].x
		if a["cell"].y != b["cell"].y:
			return a["cell"].y < b["cell"].y
		return a["color"] < b["color"])
	return threats


static func score_for_clear(n: int) -> int:
	return n * 2 + maxi(0, n - Rules.LINE_MIN) * 3


# --- tools -----------------------------------------------------------------


## Removes a marble. False if the cell was already empty, so the caller can
## decline to spend a charge on a no-op.
static func smash_marble(board: Board, p: Vector2i) -> bool:
	if not Board.in_bounds(p.x, p.y) or board.is_empty_at(p.x, p.y):
		return false
	board.clear_at(p.x, p.y)
	return true


## Exchanges two marbles' colours. Both cells must hold a marble and they must
## differ — swapping a colour with itself would silently burn a charge.
##
## Deliberately a swap rather than a recolour: it rearranges what the board
## already gave you instead of conjuring a colour from nothing, which keeps it
## tactical rather than a "win a line" button.
static func swap_marble_colors(board: Board, a: Vector2i, b: Vector2i) -> bool:
	if not Board.in_bounds(a.x, a.y) or not Board.in_bounds(b.x, b.y):
		return false
	var color_a := board.at(a.x, a.y)
	var color_b := board.at(b.x, b.y)
	if color_a == Board.EMPTY or color_b == Board.EMPTY or color_a == color_b:
		return false
	board.set_at(a.x, a.y, color_b)
	board.set_at(b.x, b.y, color_a)
	return true


## Clears a cell and the eight around it — up to nine marbles, fewer at an edge.
## Returns how many were removed so the caller can decline an empty patch.
##
## Deliberately scores nothing, like the hammer: the bomb's job is to open space
## on a board that has closed up, and paying points for it would turn it into a
## scoring move you would fire on a healthy board.
static func bomb_at(board: Board, p: Vector2i) -> int:
	var removed := 0
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var rr := p.x + dr
			var cc := p.y + dc
			if not Board.in_bounds(rr, cc) or board.is_empty_at(rr, cc):
				continue
			board.clear_at(rr, cc)
			removed += 1
	return removed


## Redistributes the colours already on the board across the cells they already
## occupy — same marbles, same count, new arrangement. False when the shuffle
## could not change anything, so the caller can decline to spend a charge:
## fewer than two marbles, or every marble the same colour.
##
## Occupancy is preserved rather than re-scattered. Moving marbles to different
## CELLS would redraw the free space the player has been working with all turn,
## which reads as the board being replaced rather than stirred — and it would
## let the tool manufacture open lanes, a far bigger effect than the "my
## colours are in the wrong places" problem it exists to solve.
##
## Any lines the new arrangement completes are the caller's to resolve.
static func shuffle_board_colors(board: Board) -> bool:
	var cells := board.occupied_cells()
	if cells.size() < 2:
		return false

	var colors: Array[int] = []
	for p in cells:
		colors.append(board.at(p.x, p.y))

	var all_same := true
	for color in colors:
		if color != colors[0]:
			all_same = false
			break
	if all_same:
		return false

	# Retry rather than accept a shuffle that landed back on the original
	# arrangement — on a board with few marbles that is likely enough to be
	# worth guarding, and it would look like the tool silently did nothing.
	# Bounded, because returning false costs the player a charge either way.
	for _attempt in 8:
		var shuffled: Array[int] = colors.duplicate()
		for i in range(shuffled.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: int = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = tmp

		var changed := false
		for i in shuffled.size():
			if shuffled[i] != colors[i]:
				changed = true
				break
		if changed:
			for i in shuffled.size():
				board.set_at_cell(cells[i], shuffled[i])
			return true
	return false


# --- spawning --------------------------------------------------------------


## Assigns each already-decided colour to an empty cell.
##
## With blocking on, it prefers the board's most urgent near-complete lines,
## placing a DIFFERENT colour there to block, falling back to a random empty
## cell when no block is available or useful for that colour. This is the "AI"
## behind the difficulty: it does not change what colours spawn, only where
## they land. The caller decides WHEN blocking is allowed — each world has its
## own per-turn chance.
##
## Returns {cells: Array[Vector2i], blocked: bool}.
static func assign_spawn_cells(
	board: Board,
	colors: Array[int],
	min_block_length: int = 3,
	enable_blocking: bool = true,
	color_count: int = Rules.COLORS,
) -> Dictionary:
	var free := board.empty_cells()
	var to_place := mini(colors.size(), free.size())
	var assigned: Array[Vector2i] = []
	if to_place == 0:
		return {"cells": assigned, "blocked": false}

	var threats: Array[Dictionary] = []
	if enable_blocking:
		threats = find_top_threats(board, min_block_length, color_count)

	var used := {}
	var blocked := false

	for i in to_place:
		var color := colors[i]
		var target := Vector2i(-1, -1)
		for t in threats:
			if t["color"] != color and not used.has(t["cell"]):
				target = t["cell"]
				break

		var idx := -1
		if target.x != -1:
			idx = free.find(target)

		# The web version calls findIndex here and passes the result straight
		# to splice. On -1 that silently removes the LAST free cell instead of
		# the intended one — a wrong-but-plausible placement rather than a
		# crash, which is the worst kind of bug to inherit. Treated as "no
		# block available" instead.
		if idx == -1:
			idx = rng.randi_range(0, free.size() - 1)
		else:
			blocked = true

		var picked := free[idx]
		free.remove_at(idx)
		used[picked] = true
		assigned.append(picked)

	return {"cells": assigned, "blocked": blocked}
