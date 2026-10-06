## The 9x9 field.
##
## Ported from the web version's `Board = (ColorIndex | null)[][]`, with two
## representation changes made deliberately:
##
## **Flat storage, not an array of arrays.** One PackedInt32Array of SIZE*SIZE
## ints. GDScript's nested Arrays are reference types, so an array-of-arrays
## board would share its rows with any copy — `duplicate()` on the outer array
## copies the row references, not the rows, and a "copy" would mutate its
## original. Flat storage makes `duplicate()` mean what it says.
##
## **EMPTY is -1, not null.** A PackedInt32Array cannot hold null, and a typed
## int is what makes the packed array worth having. Every read goes through
## `at()` and every emptiness test through `is_empty_at()`, so the sentinel
## does not leak into callers.
##
## ## Cells are Vector2i(r, c) — x is the ROW, y is the COLUMN
##
## This is worth reading twice, because it inverts the usual Vector2i(x, y)
## screen convention and a silent r/c swap is the easiest bug to introduce
## while porting. It is this way round so every line of the port maps 1:1 onto
## the TypeScript, which is written in (r, c) throughout; flipping at the
## boundary would mean flipping in dozens of places instead of documenting it
## once. Use `Board.cell(r, c)` rather than writing Vector2i literals.
class_name Board
extends RefCounted

## Sentinel for an unoccupied cell. Never compare against this directly from
## outside; use `is_empty_at()`.
const EMPTY := -1

var _cells: PackedInt32Array


func _init(cells: PackedInt32Array = PackedInt32Array()) -> void:
	if cells.is_empty():
		_cells = PackedInt32Array()
		_cells.resize(Rules.SIZE * Rules.SIZE)
		_cells.fill(EMPTY)
	else:
		assert(cells.size() == Rules.SIZE * Rules.SIZE, "board must be SIZE*SIZE")
		_cells = cells


## Build a cell. Prefer this to a Vector2i literal — see the note above about
## x being the row.
static func cell(r: int, c: int) -> Vector2i:
	return Vector2i(r, c)


static func in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < Rules.SIZE and c >= 0 and c < Rules.SIZE


func duplicate_board() -> Board:
	return Board.new(_cells.duplicate())


## Colour at (r, c), or EMPTY. Out of bounds reads as EMPTY rather than
## erroring: callers scan outward from a cell and relying on bounds checks at
## every site is how an off-by-one becomes a crash.
func at(r: int, c: int) -> int:
	if not in_bounds(r, c):
		return EMPTY
	return _cells[r * Rules.SIZE + c]


func at_cell(p: Vector2i) -> int:
	return at(p.x, p.y)


func set_at(r: int, c: int, color: int) -> void:
	if not in_bounds(r, c):
		return
	_cells[r * Rules.SIZE + c] = color


func set_at_cell(p: Vector2i, color: int) -> void:
	set_at(p.x, p.y, color)


func is_empty_at(r: int, c: int) -> bool:
	return at(r, c) == EMPTY


func clear_at(r: int, c: int) -> void:
	set_at(r, c, EMPTY)


func empty_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			if is_empty_at(r, c):
				out.append(Board.cell(r, c))
	return out


func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			if not is_empty_at(r, c):
				out.append(Board.cell(r, c))
	return out


func marble_count() -> int:
	var n := 0
	for i in _cells.size():
		if _cells[i] != EMPTY:
			n += 1
	return n


## Count of each colour on the board, indexed by colour.
##
## A colour at or beyond `color_count` is skipped rather than counted. That is
## not defensive padding: a board can outlive a world change and still hold a
## colour the new world does not use, and counting it would index past the end
## of the weights array in the spawn picker.
func color_counts(color_count: int = Rules.COLORS) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(color_count)
	counts.fill(0)
	for i in _cells.size():
		var color := _cells[i]
		if color != EMPTY and color >= 0 and color < color_count:
			counts[color] += 1
	return counts
