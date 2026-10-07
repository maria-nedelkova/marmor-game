## The game's sounds, each built from Synth and cached as a playable stream.
##
## Ported from the web version's `sound.ts`. The character of each is carried
## over rather than the exact node graph — see synth.gd on why these are
## rendered once instead of played live.
class_name Sfx

const CLICK := "click"
const SELECT := "select"
const PLACE := "place"
const CLEAR := "clear"
const BOO := "boo"
const WIN := "win"

## Built on first use and kept. Eight short mono buffers at 22kHz is well under
## a megabyte, and rebuilding one mid-turn would stutter.
static var _cache: Dictionary = {}


static func stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = Synth.to_stream(_render(name))
	return _cache[name]


static func _render(name: String) -> PackedFloat32Array:
	match name:
		CLICK:
			return _click()
		SELECT:
			return Synth.blip(520.0, 0.05, "square", 0.10)
		PLACE:
			return _place()
		CLEAR:
			return _clear()
		BOO:
			return _boo()
		WIN:
			return _win()
		_:
			return PackedFloat32Array()


## A key being pressed: a high noise transient for the contact, and a fast
## downward sweep for the body of the key travelling.
##
## Kept quieter and drier than the gameplay sounds. A UI click can fire many
## times in a row and should not compete with the board's own effects.
static func _click() -> PackedFloat32Array:
	var out := Synth.noise_burst(0.025, 0.07, 5200.0, 11)
	return Synth.mix_into(out, Synth.blip(240.0, 0.045, "square", 0.075, 130.0), 0)


## A marble settling, or a spawn landing: a short downward sweep with a noise
## tick over it for the contact.
static func _place() -> PackedFloat32Array:
	var out := Synth.blip(300.0, 0.06, "square", 0.14, 220.0)
	return Synth.mix_into(out, Synth.noise_burst(0.04, 0.06, 3000.0, 23), 0)


## A line clearing: a rising arcade chime over a sub-bass thump.
##
## The web staggers its voices with setTimeout and scales their count with the
## line's length. Rendered ahead of time there is no timer to stagger with, so
## the voices are mixed in at sample offsets — which is the same thing, and
## exact rather than at the mercy of the event loop.
##
## Fixed at five voices rather than scaling with length: the stream is built
## once and cached, and a per-length variant would mean six near-identical
## buffers for a difference most players would not name.
static func _clear() -> PackedFloat32Array:
	var out := Synth.blip(90.0, 0.18, "sine", 0.22, 55.0)
	for i in 5:
		var freq := 440.0 * pow(2.0, float(i) / 6.0)
		var offset := int(i * 0.045 * Synth.RATE)
		out = Synth.mix_into(out, Synth.blip(freq, 0.16, "square", 0.12), offset)
	return out


## The crowd jeering when the board fills: three detuned sawtooth voices, each
## bending down at its own rate so they beat against each other. The detune is
## what makes it a jeer rather than a chord.
static func _boo() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var voices := [
		[146.0, 104.0, 0.09],
		[152.0, 108.0, 0.085],
		[139.0, 99.0, 0.08],
	]
	for v in voices:
		out = Synth.mix_into(out, Synth.blip(v[0], 0.55, "saw", v[2], v[1], 0.05), 0)
	return out


## The King falling: a short ascending fanfare.
static func _win() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var notes := [392.0, 523.0, 659.0, 784.0]
	for i in notes.size():
		var offset := int(i * 0.11 * Synth.RATE)
		out = Synth.mix_into(out, Synth.blip(notes[i], 0.22, "square", 0.13), offset)
	# A low landing thump under the last note, for the pedestal.
	return Synth.mix_into(out, Synth.blip(110.0, 0.3, "sine", 0.18, 60.0), int(0.33 * Synth.RATE))
