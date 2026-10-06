## The player's permanent progress: which worlds are unlocked, and the best
## score on each.
##
## This is NOT the web version's `progress.ts`. That file is crash recovery for
## a single run — sessionStorage, a 30-minute freshness window, deliberately
## gone when the tab closes. This is the opposite: it is meant to survive
## forever, and it is what the level map reads.
##
## ## What resets and what does not
##
## **Scores reset monthly, unlocks never.** The monthly wipe is what gives the
## leaderboard a fresh set of leaders (PLAN.md section 3). Taking someone's
## unlocked worlds away with it would make a month boundary feel like a
## punishment for having played, so progression is permanent and only the
## scoreboard turns over.
##
## ## The monthly total
##
## It is the **sum of your best score on each world**, not the sum of every
## clear. Every world is replayable forever, so "each clear adds" would make
## grinding NEONIA-1 the fastest way to climb and the board would reward
## repetition over depth. Beating your own record still raises the total.
##
## ## Hostile reads
##
## Every load is treated as hostile — the file is JSON in user://, which is a
## plain text file a player can edit, and a stale build may have written a
## shape this one does not expect. Anything unexpected degrades to "no
## progress" rather than propagating a bad value into the map. Scores are also
## bounded per world, because a hand-edited file claiming a million points
## would quietly own the leaderboard.
class_name PlayerProgress

const SAVE_PATH := "user://progress.json"

## Worlds are keyed by their stable `id`, never by index — see worlds.gd. An
## index would reassign every unlock if a world were ever inserted.
var bests: Dictionary = {}
## Highest world index the player has unlocked. 0 means only NEONIA-1.
var unlocked_through: int = 0
## Year*12 + month of the period `bests` belongs to, so a month change is
## detectable without storing a date format.
var period: int = 0


static func current_period() -> int:
	var d := Time.get_datetime_dict_from_system()
	return int(d["year"]) * 12 + int(d["month"])


## A score above what a world's target and multiplier permit is not reachable
## honestly. Generous rather than tight — the point is to reject a fabricated
## number, not to police a very good run.
static func score_ceiling(world_index: int) -> int:
	return int(Worlds.get_world(world_index)["target"]) * 100


func is_unlocked(world_index: int) -> bool:
	return world_index >= 0 and world_index <= unlocked_through


func best_for(world_index: int) -> int:
	var id: String = Worlds.get_world(world_index)["id"]
	return int(bests.get(id, 0))


## Sum of bests across every world. The monthly leaderboard figure.
func monthly_total() -> int:
	var total := 0
	for i in Worlds.COUNT:
		total += best_for(i)
	return total


## Records a cleared world. Returns true if anything changed, so the caller can
## skip a write.
##
## Clearing also unlocks the next world — that is the only way unlocks advance.
func record_clear(world_index: int, score: int) -> bool:
	if world_index < 0 or world_index >= Worlds.COUNT:
		return false

	var changed := false
	var id: String = Worlds.get_world(world_index)["id"]
	var capped := clampi(score, 0, score_ceiling(world_index))
	if capped > int(bests.get(id, 0)):
		bests[id] = capped
		changed = true

	if world_index == unlocked_through and world_index + 1 < Worlds.COUNT:
		unlocked_through = world_index + 1
		changed = true

	return changed


## Wipes the scores if the stored period is not the current one, keeping
## unlocks. Returns true if a reset happened.
func roll_period_if_needed() -> bool:
	var now := current_period()
	if period == now:
		return false
	bests = {}
	period = now
	return true


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"unlocked_through": unlocked_through,
		"period": period,
		"bests": bests.duplicate(),
	}


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		# Nothing to do. Play continues; only the record is lost.
		return
	file.store_string(JSON.stringify(to_dict()))
	file.close()


static func load_progress() -> PlayerProgress:
	var progress := PlayerProgress.new()
	progress.period = current_period()

	if not FileAccess.file_exists(SAVE_PATH):
		return progress
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return progress
	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	return from_dict(parsed)


## Split out from load_progress so the validation is testable without touching
## the filesystem.
static func from_dict(parsed: Variant) -> PlayerProgress:
	var progress := PlayerProgress.new()
	progress.period = current_period()

	if typeof(parsed) != TYPE_DICTIONARY:
		return progress
	var data: Dictionary = parsed

	var stored_period := 0
	if typeof(data.get("period")) == TYPE_FLOAT or typeof(data.get("period")) == TYPE_INT:
		stored_period = int(data["period"])

	if typeof(data.get("unlocked_through")) == TYPE_FLOAT or typeof(data.get("unlocked_through")) == TYPE_INT:
		progress.unlocked_through = clampi(int(data["unlocked_through"]), 0, Worlds.COUNT - 1)

	# A save from a previous month keeps its unlocks and loses its scores.
	if stored_period != progress.period:
		return progress

	var stored_bests: Variant = data.get("bests")
	if typeof(stored_bests) != TYPE_DICTIONARY:
		return progress

	for key in (stored_bests as Dictionary):
		if typeof(key) != TYPE_STRING:
			continue
		var index := Worlds.index_of(key)
		if index == -1:
			continue  # a world that no longer exists
		var value: Variant = (stored_bests as Dictionary)[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			continue
		progress.bests[key] = clampi(int(value), 0, score_ceiling(index))

	return progress
