## Tools: the player's answer to the ladder's escalation.
##
## Ported from the web version's `src/game/tools.ts`. This is the one feature
## the Swift port never had, so the TypeScript is the only prior art.
##
## Each world from 2 to 7 unlocks one, and each unlock answers the pressure
## that same world introduces — the world hands you a problem and the means to
## deal with it. Only world 8 unlocks nothing, so the finale is about using
## what you hold well rather than learning one more button.
##
## The six run small-to-large on purpose: hammer (one marble), flask (two),
## dice (the queue), pouch (every marble on the board), bomb (nine at once),
## crystal ball (information rather than force). A player arriving at world 7
## has a strictly bigger toolkit than one at world 3, which is what keeps the
## late worlds survivable without flattening them.
##
## Charges are not bought. A currency would mean an economy, a shop, and a
## second balance surface, and it would make a puzzle game feel free-to-play;
## unlocking by progress gets the same "something new each world" for none of
## that.
##
## ## Two open items, deliberately not decided here
##
## 1. **The `answers` copy says "Round 2", "Round 3" and so on.** Ported
##    verbatim, because the port is meant to be faithful before it is
##    improved. Those worlds have names now (SULFUR-KOR, CRYSTALLOS...), so
##    this copy should probably be rewritten to use them. That is a writing
##    decision, not a porting one.
## 2. **The charge economy was tuned against a flat 100-point target**, which
##    now escalates per world (PLAN.md section 3). Whether one hammer still
##    means the same thing in GALACTIC CORE as in NEONIA-1 is an open
##    question — it is listed in PLAN.md and is not answered by this file.
class_name Tools

const HAMMER := "hammer"
const SWAP := "swap"
const REROLL := "reroll"
const SHUFFLE := "shuffle"
const BOMB := "bomb"
const FORESIGHT := "foresight"

const TOOLS: Array[Dictionary] = [
	{
		"id": HAMMER,
		"name": "Hammer",
		"unlocks_at": 1,
		"description": "Smash any one marble off the board.",
		"answers": "Round 2 starts spiking your near-complete lines; the hammer takes the spike back off.",
	},
	{
		"id": SWAP,
		"name": "Flask",
		"unlocks_at": 2,
		"description": "Transmute: exchange the colours of two marbles.",
		"answers": "Round 3's eighth colour leaves more odd ones out; swapping rearranges rather than conjures.",
	},
	{
		"id": REROLL,
		"name": "Dice",
		"unlocks_at": 3,
		"description": "Throw again: reshuffle what's coming in Next up.",
		"answers": "Round 4 drops four marbles a turn, so a bad queue costs more.",
	},
	{
		"id": SHUFFLE,
		"name": "Pouch",
		"unlocks_at": 4,
		"description": "Stir the bag: redistribute every colour on the board.",
		"answers": "Round 5 lands one of the four unannounced, so the board drifts into arrangements you never chose. The pouch is the big sibling of the dice — that one re-rolls what is coming, this one re-rolls what is already down.",
	},
	{
		"id": BOMB,
		"name": "Bomb",
		"unlocks_at": 5,
		"description": "Blow a hole: clear a marble and the eight around it.",
		"answers": "Round 6 makes like colours clump together; nine cells at once is what breaks a clump open.",
	},
	{
		"id": FORESIGHT,
		"name": "Crystal Ball",
		"unlocks_at": 6,
		"description": "See ahead: reveal where this turn's marbles will land.",
		"answers": "Round 7 starts you nine marbles down, and on a crowded board it is WHERE the next ones land, not what colour they are, that decides whether you had a move.",
	},
]

## Zero-based world index from which unused charges carry over instead of
## resetting.
##
## It used to be the world after the last unlock. With six tools the unlocks
## run to world 7, and waiting for them to finish would leave accumulation as a
## single-world footnote — so it stays at 5 and the two phases deliberately
## overlap. A tool unlocking at or after this index still arrives with exactly
## one charge, because `grant_charges` adds to a previous balance of zero; it
## simply never has a refresh phase.
const ACCUMULATE_FROM_ROUND := 5


## A charges dictionary with every tool at zero.
##
## Returned fresh each call rather than held as a const. GDScript Dictionaries
## are reference types, so a shared constant handed to a caller that mutated it
## would corrupt every later grant — and `const` would not prevent that, since
## it freezes the binding and (for a const Dictionary) its contents, which
## would instead make a legitimate write fail at runtime far from here.
static func no_charges() -> Dictionary:
	var out := {}
	for tool_def in TOOLS:
		out[tool_def["id"]] = 0
	return out


static func is_unlocked(tool_def: Dictionary, world_index: int) -> bool:
	return world_index >= tool_def["unlocks_at"]


static func unlocked_at(world_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tool_def in TOOLS:
		if is_unlocked(tool_def, world_index):
			out.append(tool_def)
	return out


## The tool unlocked by arriving at this world, or an empty Dictionary — used
## to call it out on the world-cleared screen.
static func tool_unlocked_at(world_index: int) -> Dictionary:
	for tool_def in TOOLS:
		if tool_def["unlocks_at"] == world_index:
			return tool_def
	return {}


static func find_tool(id: String) -> Dictionary:
	for tool_def in TOOLS:
		if tool_def["id"] == id:
			return tool_def
	return {}


## Charges the player holds on entering `world_index`.
##
## Below ACCUMULATE_FROM_ROUND every unlocked tool is set to exactly one,
## discarding anything unspent — use it or lose it. From that index on, the
## world's grant is added to what survived instead, so saving a charge through
## an easy world pays for a hard one.
##
## Always returns a NEW dictionary. The web version spreads into a fresh object
## for the same reason; in GDScript it matters more, because returning the
## argument would alias the caller's state.
static func grant_charges(previous: Dictionary, world_index: int) -> Dictionary:
	var next := no_charges()
	for tool_def in TOOLS:
		if not is_unlocked(tool_def, world_index):
			continue
		var id: String = tool_def["id"]
		if world_index >= ACCUMULATE_FROM_ROUND:
			# `.get(id, 0)` rather than indexing: a snapshot written by an older
			# build can be missing a tool that did not exist yet.
			next[id] = int(previous.get(id, 0)) + 1
		else:
			next[id] = 1
	return next


## Spends one charge. Returns an unchanged COPY when there is nothing to spend,
## so a caller cannot accidentally mutate shared state by holding the result.
static func spend_charge(charges: Dictionary, id: String) -> Dictionary:
	var out := charges.duplicate()
	if int(out.get(id, 0)) <= 0:
		return out
	out[id] = int(out[id]) - 1
	return out


static func has_charge(charges: Dictionary, id: String) -> bool:
	return int(charges.get(id, 0)) > 0
