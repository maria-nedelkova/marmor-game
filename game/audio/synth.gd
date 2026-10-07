## Sound synthesis: pure functions from parameters to samples.
##
## Ported from the web version's `src/audio/sound.ts`, which builds every effect
## from oscillators and noise rather than shipping audio files. Same principle
## here, and for the same reasons: nothing to license, nothing to download, and
## a sound can be retuned by changing a number rather than by re-exporting a
## wav.
##
## ## Rendered once, not streamed
##
## Web Audio is a live node graph — the web version creates an oscillator and a
## gain per sound, wires them to the destination and schedules automation.
## Godot can do that with an AudioStreamGenerator, but filling a generator
## buffer means keeping up with playback on the main thread, and glitching when
## you do not. Each effect is rendered into a buffer ONCE here, cached, and
## replayed. That also makes the sound design pure functions from parameters to
## `PackedFloat32Array`, with no reference to any audio node — so it is
## testable without an audio device, which is how sfx_test checks it.
##
## Nothing in this file touches the scene tree or the AudioServer.
class_name Synth

const RATE := 22050


## Attack-decay envelope. Linear up, exponential down — the exponential tail is
## what makes a blip sound struck rather than switched off, and it is what the
## web version's `exponentialRampToValueAtTime` gives for free.
static func envelope(index: int, count: int, attack: float, decay: float, peak: float) -> float:
	var t := float(index) / float(RATE)
	var attack_time := maxf(attack, 0.0001)
	if t < attack_time:
		return peak * (t / attack_time)
	var fall := (t - attack_time) / maxf(decay, 0.0001)
	if fall >= 1.0:
		return 0.0
	# exp curve from peak down to ~0.0001 of it, matching Web Audio's ramp.
	return peak * pow(0.0001, fall)


## Band-limited step, used to round the discontinuities in square and sawtooth.
##
## A naive `phase < 0.5 ? 1 : -1` aliases audibly on the brighter blips —
## Web Audio's built-in oscillators are band-limited and a hand-rolled one is
## not. This is the cheap correction the Swift port uses for the same reason.
static func _poly_blep(phase: float, step: float) -> float:
	if phase < step:
		var t := phase / step
		return t + t - t * t - 1.0
	if phase > 1.0 - step:
		var t := (phase - 1.0) / step
		return t * t + t + t + 1.0
	return 0.0


static func _wave(kind: String, phase: float, step: float) -> float:
	match kind:
		"sine":
			return sin(TAU * phase)
		"triangle":
			return 4.0 * absf(phase - 0.5) - 1.0
		"saw":
			return (2.0 * phase - 1.0) - _poly_blep(phase, step)
		_:
			var square := 1.0 if phase < 0.5 else -1.0
			square += _poly_blep(phase, step)
			square -= _poly_blep(fmod(phase + 0.5, 1.0), step)
			return square


## A single tone with an envelope, optionally sweeping in pitch.
##
## `sweep_to` is exponential, like the web's `exponentialRampToValueAtTime` —
## a linear sweep over the same range sounds like it slows down at the end,
## because pitch is perceived logarithmically.
static func blip(
	freq: float,
	duration: float,
	kind: String = "square",
	peak: float = 0.18,
	sweep_to: float = 0.0,
	attack: float = 0.005,
) -> PackedFloat32Array:
	var count := int(duration * RATE) + int(0.02 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	var phase := 0.0
	for i in count:
		var progress := clampf(float(i) / maxf(1.0, duration * RATE), 0.0, 1.0)
		var f := freq
		if sweep_to > 0.0:
			f = freq * pow(sweep_to / freq, progress)
		var step := f / float(RATE)
		out[i] = _wave(kind, phase, step) * envelope(i, count, attack, duration, peak)
		phase = fmod(phase + step, 1.0)
	return out


## Filtered noise. The web highpasses it so a burst reads as a click or a hiss
## rather than as a thud; this is a one-pole highpass, which is gentler than a
## biquad but enough at these durations.
static func noise_burst(
	duration: float, peak: float = 0.12, highpass_hz: float = 2200.0, seed_value: int = 1
) -> PackedFloat32Array:
	var count := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	var rng := RandomNumberGenerator.new()
	# Seeded: an effect rendered once and replayed should sound the same every
	# run, and an unseeded burst would differ between launches.
	rng.seed = seed_value

	var dt := 1.0 / float(RATE)
	var rc := 1.0 / (TAU * maxf(highpass_hz, 1.0))
	var alpha := rc / (rc + dt)
	var previous_in := 0.0
	var previous_out := 0.0

	for i in count:
		var sample := rng.randf_range(-1.0, 1.0)
		var filtered := alpha * (previous_out + sample - previous_in)
		previous_in = sample
		previous_out = filtered
		out[i] = filtered * envelope(i, count, 0.002, duration, peak)
	return out


## Adds `src` into `dest` at a sample offset, growing `dest` if needed.
##
## Mixing into one buffer is how the multi-part effects are built — the web
## staggers its clear chime's voices with setTimeout, which cannot work for a
## sound rendered ahead of time.
static func mix_into(dest: PackedFloat32Array, src: PackedFloat32Array, offset: int) -> PackedFloat32Array:
	var needed := offset + src.size()
	if dest.size() < needed:
		dest.resize(needed)
	for i in src.size():
		dest[offset + i] = dest[offset + i] + src[i]
	return dest


## Packs samples into a playable stream, clipping anything the mix pushed past
## full scale rather than letting it wrap into noise.
static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
