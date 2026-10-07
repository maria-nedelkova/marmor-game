## Plays the effects, and owns whether sound is on.
##
## A pool of players rather than one, because effects overlap constantly — a
## clear fires while the place that caused it is still ringing. With a single
## player each new sound would cut the last one off mid-tail, which is the most
## obvious way for synthesised audio to sound cheap.
extends Node

## Eight is comfortably more than the game ever stacks: a move, the clear it
## causes, and up to four spawns. The oldest is reused if they all run out,
## which clips one tail rather than dropping a sound.
const VOICES := 8

var muted := false:
	set(value):
		muted = value
		if muted:
			for player in _players:
				player.stop()

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func play(name: String) -> void:
	if muted or _players.is_empty():
		return
	var stream := Sfx.stream(name)
	if stream == null:
		return
	# Prefer a free player; fall back to round-robin so a burst still sounds.
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	var reused := _players[_next]
	_next = (_next + 1) % _players.size()
	reused.stream = stream
	reused.play()
