## The synth and the effects built from it.
##
## All of this is checkable without an audio device, which is the point of
## keeping the sound design as pure functions from parameters to samples (see
## synth.gd). What is asserted here is the things that are audibly wrong when
## they break — silence, clipping, a tone at the wrong pitch, an envelope that
## never decays — rather than sample-for-sample output, which would be a
## change-detector test.
extends GdUnitTestSuite


func _peak(samples: PackedFloat32Array) -> float:
	var highest := 0.0
	for s in samples:
		highest = maxf(highest, absf(s))
	return highest


## Counts zero crossings, which gives the fundamental closely enough to tell
## 520Hz from 220Hz without an FFT.
func _estimated_hz(samples: PackedFloat32Array, window: int) -> float:
	var crossings := 0
	var limit := mini(window, samples.size() - 1)
	for i in range(1, limit):
		if (samples[i - 1] < 0.0) != (samples[i] < 0.0):
			crossings += 1
	return (crossings * 0.5) / (float(limit) / float(Synth.RATE))


# --- envelope ----------------------------------------------------------------


func test_the_envelope_rises_then_decays_to_silence() -> void:
	var peak := 0.5
	var attack := 0.01
	var decay := 0.2
	assert_float(Synth.envelope(0, 0, attack, decay, peak)).is_equal_approx(0.0, 0.001)

	var at_peak: float = Synth.envelope(int(attack * Synth.RATE), 0, attack, decay, peak)
	assert_float(at_peak).is_equal_approx(peak, 0.02)

	# Well past attack + decay it must be silent, not merely quiet — a tail that
	# never reaches zero is a click when the buffer ends.
	var after: float = Synth.envelope(int((attack + decay) * Synth.RATE) + 10, 0, attack, decay, peak)
	assert_float(after).is_equal(0.0)


func test_the_envelope_decays_rather_than_cutting_off() -> void:
	var quarter: float = Synth.envelope(int(0.05 * Synth.RATE), 0, 0.001, 0.2, 1.0)
	var half: float = Synth.envelope(int(0.10 * Synth.RATE), 0, 0.001, 0.2, 1.0)
	assert_float(half).is_less(quarter)
	assert_float(quarter).is_greater(0.0)


# --- oscillators -------------------------------------------------------------


func test_a_blip_is_audible_and_within_full_scale() -> void:
	for kind in ["square", "sine", "triangle", "saw"]:
		var samples := Synth.blip(440.0, 0.1, kind, 0.3)
		assert_float(_peak(samples)) \
			.override_failure_message("%s produced silence" % kind).is_greater(0.05)
		assert_float(_peak(samples)) \
			.override_failure_message("%s clipped" % kind).is_less_equal(1.0)


func test_a_blip_plays_the_pitch_it_was_asked_for() -> void:
	for hz in [220.0, 440.0, 880.0]:
		var samples := Synth.blip(hz, 0.25, "square", 0.4)
		# Measured early, before the envelope buries the waveform in noise.
		var measured := _estimated_hz(samples, int(0.08 * Synth.RATE))
		assert_float(measured) \
			.override_failure_message("asked %f, measured %f" % [hz, measured]) \
			.is_equal_approx(hz, hz * 0.12)


## The sweep is exponential, so the pitch at the halfway point is the geometric
## mean of the ends, not the arithmetic one. A linear sweep would land near 660
## here instead of 440 and sound like it slowed down at the end.
func test_a_sweep_moves_the_pitch_exponentially() -> void:
	var samples := Synth.blip(880.0, 0.4, "square", 0.4, 220.0)
	var early := _estimated_hz(samples, int(0.03 * Synth.RATE))
	assert_float(early).is_equal_approx(880.0, 160.0)

	var midpoint := int(0.2 * Synth.RATE)
	var tail := samples.slice(midpoint, midpoint + int(0.03 * Synth.RATE))
	var middle := _estimated_hz(tail, tail.size())
	assert_float(middle).override_failure_message("midpoint measured %f" % middle) \
		.is_equal_approx(440.0, 110.0)


func test_noise_is_noisy_rather_than_periodic() -> void:
	var samples := Synth.noise_burst(0.1, 0.4, 2000.0)
	assert_float(_peak(samples)).is_greater(0.02)
	# A tone at this amplitude would cross zero a few hundred times in 0.1s;
	# filtered noise crosses far more often.
	var crossings := 0
	for i in range(1, samples.size()):
		if (samples[i - 1] < 0.0) != (samples[i] < 0.0):
			crossings += 1
	assert_int(crossings).is_greater(800)


## Rendered once and replayed, so an unseeded burst would differ every launch.
func test_noise_is_the_same_every_time() -> void:
	var a := Synth.noise_burst(0.05, 0.2, 2000.0, 7)
	var b := Synth.noise_burst(0.05, 0.2, 2000.0, 7)
	assert_int(a.size()).is_equal(b.size())
	for i in a.size():
		assert_float(a[i]).is_equal(b[i])


# --- mixing ------------------------------------------------------------------


func test_mixing_grows_the_buffer_and_sums_in_place() -> void:
	var base := PackedFloat32Array([0.1, 0.1])
	var mixed := Synth.mix_into(base, PackedFloat32Array([0.2, 0.2]), 1)
	assert_int(mixed.size()).is_equal(3)
	assert_float(mixed[0]).is_equal_approx(0.1, 0.0001)
	assert_float(mixed[1]).is_equal_approx(0.3, 0.0001)
	assert_float(mixed[2]).is_equal_approx(0.2, 0.0001)


## Clipping is handled at pack time rather than by hoping the mix stays in
## range. Several voices summing past full scale would otherwise wrap and
## become a loud buzz — the worst possible failure for a sound effect.
func test_packing_clips_instead_of_wrapping() -> void:
	var stream := Synth.to_stream(PackedFloat32Array([3.0, -3.0, 0.0]))
	assert_int(stream.data.decode_s16(0)).is_equal(32767)
	assert_int(stream.data.decode_s16(2)).is_equal(-32767)
	assert_int(stream.data.decode_s16(4)).is_equal(0)


func test_a_stream_is_mono_sixteen_bit_at_the_synth_rate() -> void:
	var stream := Synth.to_stream(Synth.blip(440.0, 0.1))
	assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	assert_int(stream.mix_rate).is_equal(Synth.RATE)
	assert_bool(stream.stereo).is_false()


# --- the effects themselves ---------------------------------------------------


func test_every_effect_renders_something_audible() -> void:
	for name in [Sfx.CLICK, Sfx.SELECT, Sfx.PLACE, Sfx.CLEAR, Sfx.BOO, Sfx.WIN]:
		var stream := Sfx.stream(name)
		assert_object(stream).override_failure_message("%s built nothing" % name).is_not_null()
		assert_int(stream.data.size()) \
			.override_failure_message("%s is empty" % name).is_greater(1000)

		var loudest := 0
		for i in range(0, stream.data.size(), 2):
			loudest = maxi(loudest, absi(stream.data.decode_s16(i)))
		assert_int(loudest) \
			.override_failure_message("%s is silent" % name).is_greater(1000)


## Built once and reused. Rebuilding mid-turn would stutter.
func test_effects_are_cached() -> void:
	assert_object(Sfx.stream(Sfx.SELECT)).is_same(Sfx.stream(Sfx.SELECT))


func test_an_unknown_effect_is_empty_rather_than_a_crash() -> void:
	assert_int(Sfx.stream("not_a_sound").data.size()).is_equal(0)


## The multi-voice effects have to be longer than any one of their voices, or
## the mixing offsets were ignored and everything landed on top of each other.
func test_the_layered_effects_are_longer_than_a_single_voice() -> void:
	var single := Synth.blip(440.0, 0.16, "square", 0.12).size()
	for name in [Sfx.CLEAR, Sfx.WIN]:
		var samples := Sfx.stream(name).data.size() / 2
		assert_int(samples) \
			.override_failure_message("%s is only %d samples, a voice is %d" % [name, samples, single]) \
			.is_greater(single)
