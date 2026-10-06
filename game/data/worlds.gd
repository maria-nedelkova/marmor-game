## The eight worlds, as data.
##
## This file is the one PLAN.md calls out as the thing that survives: names,
## kings, score targets, difficulty dials and unlock rules in one place, with
## no engine or scene code in it. Tuning a level never means touching anything
## else, and the whole progression reads top to bottom.
##
## Two sources are merged here:
##
## - The difficulty dials are a faithful port of the web version's
##   `src/game/levels.ts`. Do not retune them while porting; get them identical
##   first, then change things deliberately.
## - The world names, kings and score targets are new (see PLAN.md sections 3
##   and 4). They have never existed in the web version.
class_name Worlds


## The King's target used to be a flat 100 for every round, with difficulty
## coming from making 100 harder to earn. It escalates now, and `multiplier`
## scales line values by the same factor (`target / 100`).
##
## Read this before retuning: because the target and the line value scale
## together, a level plays IDENTICALLY to one with a smaller target. Level 4
## at 1000 with a 10x multiplier is the same ten lines as level 1 at 100. The
## escalation is a reward change, not a difficulty change — difficulty still
## comes from the dials below. Where it bites is the monthly leaderboard:
## clearing GALACTIC CORE is worth fifty times clearing NEONIA-1, which is
## what pulls a player deeper into the map.
const WORLDS: Array[Dictionary] = [
	{
		# Stable key for save data. NEVER renamed — a player's unlock and best
		# score are stored against it, so changing one silently resets both.
		# The display name above it is free to change.
		"id": "neonia_1",
		"name": "NEONIA-1",
		"subtitle": "The Duel",
		"twist": "The classic duel: seven colors, three marbles a turn, and a King who already fights dirty.",
		"king": "plain crown, green",
		"target": 100,
		"multiplier": 1,
		"colors": 7,
		"spawn_count": 3,
		"preview_count": 3,
		"start_count": 5,
		"block_probability": 0.35,
		"block_min_run_length": 3,
		"color_affinity": 1.0,
		"spawn_on_clear": false,
	},
	{
		"id": "sulfur_kor",
		"name": "SULFUR-KOR",
		"subtitle": "Court Intrigue",
		"twist": "The court plays dirty — your almost-finished lines start getting spiked.",
		"king": "flame crown, orange",
		"target": 300,
		"multiplier": 3,
		"colors": 7,
		"spawn_count": 3,
		"preview_count": 3,
		"start_count": 5,
		"block_probability": 0.4,
		"block_min_run_length": 3,
		"color_affinity": 1.0,
		"spawn_on_clear": false,
	},
	{
		"id": "crystallos",
		"name": "CRYSTALLOS",
		"subtitle": "A Suspect Too Many",
		"twist": "An eighth color joins the court. Every line you start is now harder to finish.",
		"king": "shard crown, violet",
		"target": 600,
		"multiplier": 6,
		"colors": 8,
		"spawn_count": 3,
		"preview_count": 3,
		"start_count": 5,
		"block_probability": 0.4,
		"block_min_run_length": 3,
		"color_affinity": 1.0,
		"spawn_on_clear": false,
	},
	{
		"id": "black_hole_04",
		"name": "BLACK HOLE 04",
		"subtitle": "The Flood",
		"twist": "Four marbles a turn instead of three. Space is the enemy now.",
		"king": "faceless, event horizon",
		"target": 1000,
		"multiplier": 10,
		"colors": 8,
		"spawn_count": 4,
		"preview_count": 4,
		"start_count": 5,
		"block_probability": 0.4,
		"block_min_run_length": 3,
		"color_affinity": 1.0,
		"spawn_on_clear": false,
	},
	{
		"id": "celestial_ring_station",
		"name": "CELESTIAL RING STATION",
		"subtitle": "Blind Spot",
		"twist": "Next up only shows three of the four. One marble lands unannounced.",
		"king": "visored helm, gold",
		"target": 1600,
		"multiplier": 16,
		"colors": 8,
		"spawn_count": 4,
		"preview_count": 3,
		"start_count": 5,
		"block_probability": 0.4,
		"block_min_run_length": 3,
		"color_affinity": 1.0,
		"spawn_on_clear": false,
	},
	{
		"id": "terra_former",
		"name": "TERRA-FORMER",
		"subtitle": "Sworn Enemies",
		"twist": "The marbles stop clumping in your favour — runs stall where they used to build.",
		"king": "leaf crown, green",
		"target": 2400,
		"multiplier": 24,
		"colors": 8,
		"spawn_count": 4,
		"preview_count": 3,
		"start_count": 5,
		"block_probability": 0.4,
		"block_min_run_length": 3,
		"color_affinity": 0.45,
		"spawn_on_clear": false,
	},
	{
		"id": "gaia_prime",
		"name": "GAIA PRIME",
		"subtitle": "Standing Room Only",
		"twist": "The board is already crowded before you make your first move.",
		"king": "orbital halo, cyan",
		"target": 3500,
		"multiplier": 35,
		"colors": 8,
		"spawn_count": 4,
		"preview_count": 3,
		"start_count": 9,
		"block_probability": 0.4,
		"block_min_run_length": 3,
		"color_affinity": 0.45,
		"spawn_on_clear": false,
	},
	{
		"id": "galactic_core",
		"name": "GALACTIC CORE",
		"subtitle": "The Coronation",
		"twist": "No more free turns — clearing a line no longer holds back the next wave.",
		"king": "dark silhouette",
		"target": 5000,
		"multiplier": 50,
		"colors": 8,
		"spawn_count": 4,
		"preview_count": 3,
		"start_count": 9,
		"block_probability": 0.4,
		"block_min_run_length": 3,
		"color_affinity": 0.45,
		"spawn_on_clear": true,
	},
]

const COUNT := 8


## Clamped, so a stray index can never crash the game into a missing world.
static func get_world(index: int) -> Dictionary:
	return WORLDS[clampi(index, 0, COUNT - 1)]


static func is_final(index: int) -> bool:
	return index >= COUNT - 1


## Index of a world by its save-data id, or -1. Used when loading progress:
## ids are matched by name rather than by position so that inserting a world
## later does not reassign everyone's unlocks to the wrong places.
static func index_of(id: String) -> int:
	for i in COUNT:
		if WORLDS[i]["id"] == id:
			return i
	return -1
