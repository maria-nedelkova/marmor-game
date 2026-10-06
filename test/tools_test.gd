## The tool system's tests, ported from the web version's
## `src/game/tools.test.ts`.
##
## These pin the unlock schedule and the charge economy, which is the part of
## the design most easily broken by a well-meaning edit — the two grant phases
## overlap on purpose, and that overlap looks like a bug until you read why.
extends GdUnitTestSuite


## Builds a charges dictionary from a partial one, filling the rest with zero.
## The web suite has the same helper, for the same reason: writing all six
## every time buries the one value a test is actually about.
func _charges(partial: Dictionary) -> Dictionary:
	var out := Tools.no_charges()
	for key in partial:
		out[key] = partial[key]
	return out


# --- unlock schedule -------------------------------------------------------


func test_one_tool_per_world_across_two_to_seven() -> void:
	var by_world: Array = []
	for i in Worlds.COUNT:
		var t := Tools.tool_unlocked_at(i)
		by_world.append(t.get("id", null))
	assert_array(by_world).is_equal([
		null, Tools.HAMMER, Tools.SWAP, Tools.REROLL,
		Tools.SHUFFLE, Tools.BOMB, Tools.FORESIGHT, null,
	])


func test_first_world_has_no_tools_and_the_last_has_them_all() -> void:
	assert_int(Tools.unlocked_at(0).size()).is_equal(0)
	assert_int(Tools.unlocked_at(Worlds.COUNT - 1).size()).is_equal(Tools.TOOLS.size())


func test_the_rack_only_ever_grows() -> void:
	for world in range(1, Worlds.COUNT):
		assert_int(Tools.unlocked_at(world).size()) \
			.override_failure_message("the rack shrank entering world %d" % (world + 1)) \
			.is_greater_equal(Tools.unlocked_at(world - 1).size())


# --- grant_charges: reset phase --------------------------------------------


func test_reset_phase_gives_exactly_one_of_each_unlocked_tool() -> void:
	assert_dict(Tools.grant_charges(Tools.no_charges(), 1)).is_equal(_charges({Tools.HAMMER: 1}))
	assert_dict(Tools.grant_charges(Tools.no_charges(), 3)) \
		.is_equal(_charges({Tools.HAMMER: 1, Tools.SWAP: 1, Tools.REROLL: 1}))


func test_reset_phase_discards_anything_unspent() -> void:
	var hoarded := _charges({Tools.HAMMER: 1, Tools.SWAP: 1})
	assert_dict(Tools.grant_charges(hoarded, 3)) \
		.is_equal(_charges({Tools.HAMMER: 1, Tools.SWAP: 1, Tools.REROLL: 1}))


## A stale snapshot must not hand out charges for a tool that is still locked.
func test_a_locked_tool_stays_at_zero_despite_a_stale_value() -> void:
	var bogus := _charges({Tools.HAMMER: 1, Tools.REROLL: 5, Tools.FORESIGHT: 9})
	assert_dict(Tools.grant_charges(bogus, 1)).is_equal(_charges({Tools.HAMMER: 1}))


# --- grant_charges: accumulating phase -------------------------------------


func test_accumulating_phase_adds_to_what_survived() -> void:
	var leftover := _charges({Tools.HAMMER: 1, Tools.REROLL: 2, Tools.SHUFFLE: 1})
	assert_dict(Tools.grant_charges(leftover, Tools.ACCUMULATE_FROM_ROUND)).is_equal(_charges({
		Tools.HAMMER: 2, Tools.SWAP: 1, Tools.REROLL: 3, Tools.SHUFFLE: 2, Tools.BOMB: 1,
	}))


func test_banking_across_the_accumulating_worlds_is_worth_doing() -> void:
	var held := Tools.grant_charges(Tools.no_charges(), Tools.ACCUMULATE_FROM_ROUND)
	for world in range(Tools.ACCUMULATE_FROM_ROUND + 1, Worlds.COUNT):
		held = Tools.grant_charges(held, world)
	assert_int(held[Tools.HAMMER]).is_equal(Worlds.COUNT - Tools.ACCUMULATE_FROM_ROUND)


func test_spending_keeps_the_ceiling_down() -> void:
	var held := Tools.grant_charges(Tools.no_charges(), Tools.ACCUMULATE_FROM_ROUND)
	held = Tools.spend_charge(held, Tools.HAMMER)
	held = Tools.grant_charges(held, Tools.ACCUMULATE_FROM_ROUND + 1)
	assert_int(held[Tools.HAMMER]).is_equal(1)


## The two phases overlap: bomb and crystal ball unlock at or after
## ACCUMULATE_FROM_ROUND, so they never see a reset world. They must still
## arrive holding exactly one, which works only because grant_charges adds to a
## previous balance of zero.
func test_a_tool_unlocking_inside_the_accumulating_phase_still_arrives_with_one() -> void:
	var checked := 0
	for tool_def in Tools.TOOLS:
		if tool_def["unlocks_at"] < Tools.ACCUMULATE_FROM_ROUND:
			continue
		checked += 1
		var granted := Tools.grant_charges(Tools.no_charges(), tool_def["unlocks_at"])
		assert_int(granted[tool_def["id"]]) \
			.override_failure_message("%s did not arrive with one charge" % tool_def["name"]) \
			.is_equal(1)
	# If the overlap is ever removed this loop would check nothing and pass.
	assert_int(checked).override_failure_message("no tool unlocks inside the accumulating phase").is_greater(0)


# --- spend_charge ----------------------------------------------------------


func test_spend_decrements_only_the_tool_used() -> void:
	var after := Tools.spend_charge(_charges({Tools.HAMMER: 2, Tools.SWAP: 1}), Tools.HAMMER)
	assert_dict(after).is_equal(_charges({Tools.HAMMER: 1, Tools.SWAP: 1}))


func test_spend_never_goes_negative() -> void:
	var empty := _charges({Tools.SWAP: 1})
	assert_dict(Tools.spend_charge(empty, Tools.HAMMER)).is_equal(empty)


func test_has_charge_gates_use() -> void:
	assert_bool(Tools.has_charge(_charges({Tools.HAMMER: 1}), Tools.HAMMER)).is_true()
	assert_bool(Tools.has_charge(Tools.no_charges(), Tools.HAMMER)).is_false()


## GDScript Dictionaries are reference types, so a function that returned its
## argument would alias the caller's state and a later write would reach back
## into it. The web version is immune by spreading into a new object; this is
## the GDScript-specific hazard the port has to answer.
func test_spend_and_grant_never_alias_their_input() -> void:
	var original := _charges({Tools.HAMMER: 2})
	var after_spend := Tools.spend_charge(original, Tools.HAMMER)
	after_spend[Tools.HAMMER] = 99
	assert_int(original[Tools.HAMMER]).is_equal(2)

	var after_noop := Tools.spend_charge(original, Tools.BOMB)
	after_noop[Tools.HAMMER] = 77
	assert_int(original[Tools.HAMMER]).is_equal(2)

	var granted := Tools.grant_charges(original, 3)
	granted[Tools.HAMMER] = 55
	assert_int(original[Tools.HAMMER]).is_equal(2)


func test_no_charges_returns_a_fresh_dictionary_each_time() -> void:
	var a := Tools.no_charges()
	a[Tools.HAMMER] = 42
	assert_int(Tools.no_charges()[Tools.HAMMER]).is_equal(0)


## A snapshot written before a tool existed is missing that key entirely.
func test_grant_tolerates_a_snapshot_missing_a_tool() -> void:
	var old_save := {Tools.HAMMER: 2}
	var granted := Tools.grant_charges(old_save, Tools.ACCUMULATE_FROM_ROUND)
	assert_int(granted[Tools.HAMMER]).is_equal(3)
	assert_int(granted[Tools.BOMB]).is_equal(1)


# --- the table itself ------------------------------------------------------


func test_every_tool_is_described() -> void:
	for tool_def in Tools.TOOLS:
		assert_int((tool_def["name"] as String).length()).is_greater(2)
		assert_int((tool_def["description"] as String).length()).is_greater(10)
		assert_int((tool_def["answers"] as String).length()).is_greater(10)
		assert_int(tool_def["unlocks_at"]).is_between(0, Worlds.COUNT - 1)

	var ids := {}
	for tool_def in Tools.TOOLS:
		ids[tool_def["id"]] = true
	assert_int(ids.size()).is_equal(Tools.TOOLS.size())


func test_no_charges_covers_every_tool() -> void:
	var keys := Tools.no_charges().keys()
	keys.sort()
	var ids: Array = []
	for tool_def in Tools.TOOLS:
		ids.append(tool_def["id"])
	ids.sort()
	assert_array(keys).is_equal(ids)


func test_find_tool_resolves_ids_and_rejects_unknown() -> void:
	assert_str(Tools.find_tool(Tools.BOMB)["name"]).is_equal("Bomb")
	assert_bool(Tools.find_tool("not_a_tool").is_empty()).is_true()
