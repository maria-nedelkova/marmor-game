import Foundation

/// The game's sound effects, each rendered to a mono buffer. Ported one for
/// one from `src/audio/sound.ts`.
///
/// The web version schedules multi-part sounds with `setTimeout` and lets the
/// Web Audio graph mix them live. Here each effect is rendered whole into a
/// single buffer with its parts mixed in at the right offsets, which is both
/// simpler to play back and testable without an audio device.
public enum Sfx {

    /// Marble picked up / selected.
    public static func select(sampleRate: Double = defaultSampleRate) -> [Float] {
        clamped(
            renderBlip(
                frequency: 520, duration: 0.05, waveform: .square, peak: 0.1,
                sampleRate: sampleRate))
    }

    /// A single glide step while a marble travels its path.
    public static func glideTick(sampleRate: Double = defaultSampleRate) -> [Float] {
        clamped(
            renderBlip(
                frequency: 760, duration: 0.03, waveform: .triangle, peak: 0.05,
                sampleRate: sampleRate))
    }

    /// Marble settles into its destination (or a spawn lands).
    public static func place<G: RandomNumberGenerator>(
        sampleRate: Double = defaultSampleRate,
        using rng: inout G
    ) -> [Float] {
        var out = renderBlip(
            frequency: 300, duration: 0.06, waveform: .square, peak: 0.14, sweepTo: 220,
            sampleRate: sampleRate)
        let noise = renderNoiseBurst(
            duration: 0.04, peak: 0.06, filterFrequency: 3000, sampleRate: sampleRate, using: &rng)
        mix(noise, into: &out, atSample: 0)
        return clamped(out)
    }

    /// Line clear — a rising multi-voice arcade chime. Pitch and voice count
    /// scale with how many marbles popped, plus a sub thump for weight.
    public static func clear(
        lineLength: Int,
        sampleRate: Double = defaultSampleRate
    ) -> [Float] {
        let voices = max(1, min(3 + (lineLength - 5) / 2, 8))
        var out: [Float] = []

        for i in 0..<voices {
            let frequency = 440 * pow(2, Double(i) / 6)
            let voice = renderBlip(
                frequency: frequency, duration: 0.16, waveform: .square, peak: 0.14,
                sampleRate: sampleRate)
            mix(voice, into: &out, at: Double(i) * 0.045, sampleRate: sampleRate)
        }

        // Sub-bass thump for arcade punch, coinciding with the first voice.
        let thump = renderBlip(
            frequency: 90, duration: 0.18, waveform: .sine, peak: 0.22, sweepTo: 55,
            sampleRate: sampleRate)
        mix(thump, into: &out, atSample: 0)

        return clamped(out)
    }

    /// Win — the Pretender dethrones the King: a short ascending fanfare.
    public static func win(sampleRate: Double = defaultSampleRate) -> [Float] {
        var out: [Float] = []
        for (i, frequency) in [392.0, 523, 659, 784, 1047].enumerated() {
            let note = renderBlip(
                frequency: frequency, duration: 0.2, waveform: .square, peak: 0.18,
                sampleRate: sampleRate)
            mix(note, into: &out, at: Double(i) * 0.11, sampleRate: sampleRate)
        }
        return clamped(out)
    }

    /// The Pretender topples off his pedestal when the table fills up — a low,
    /// wavering, detuned "Boooooo" crowd jeer. Three sawtooth voices, each
    /// with its own vibrato rate and a slight downward bend, lowpass-filtered
    /// so it reads as a vocal jeer rather than a synth chord.
    public static func pretenderBoo(sampleRate: Double = defaultSampleRate) -> [Float] {
        let duration = 0.9
        let count = sampleCount(duration, sampleRate: sampleRate)
        var out = [Float](repeating: 0, count: count)

        for (i, base) in [140.0, 150, 132].enumerated() {
            var filter = Biquad(.lowpass, frequency: 500, sampleRate: sampleRate)
            var phase = 0.0

            for n in 0..<count {
                let t = Double(n) / sampleRate

                // Pitch bends down to 85% across the sound, with vibrato on top.
                let bend = base + (base * 0.85 - base) * (t / duration)
                let vibrato = 8 * sin(2 * .pi * (5 + Double(i)) * t)
                let dt = (bend + vibrato) / sampleRate

                let raw = Waveform.sawtooth.sample(phase: phase, dt: dt)
                out[n] += Float(filter.process(raw) * booAmplitude(at: t, duration: duration))

                phase += dt
                if phase >= 1 { phase -= 1 }
            }
        }
        return clamped(out)
    }

    /// Swell in over 0.15s, hold, then decay away over the last 40%.
    private static func booAmplitude(at t: Double, duration: Double) -> Double {
        let hold = 0.12
        if t < 0.15 { return silenceFloor + (hold - silenceFloor) * (t / 0.15) }
        let sustainEnd = duration * 0.6
        if t < sustainEnd { return hold }
        let progress = (t - sustainEnd) / (duration - sustainEnd)
        return hold * pow(silenceFloor / hold, min(1, progress))
    }

    /// The King tumbles off his pedestal when the Pretender dethrones him.
    /// This is the player's win, so it plays as a bouncy, comical "boioioing"
    /// spring wobble — a decaying pitch LFO — rather than a scream, landing in
    /// a soft thud right as the fanfare kicks in.
    public static func kingFall(sampleRate: Double = defaultSampleRate) -> [Float] {
        let duration = 1.0
        let count = sampleCount(duration, sampleRate: sampleRate)
        var out = [Float](repeating: 0, count: count)

        var phase = 0.0
        for n in 0..<count {
            let t = Double(n) / sampleRate

            // Wobble depth decays exponentially, so the spring settles.
            let depth = 150 * pow(4.0 / 150.0, t / duration)
            let dt = (420 + depth * sin(2 * .pi * 12 * t)) / sampleRate

            let amplitude: Double
            if t < 0.04 {
                amplitude = silenceFloor + (0.2 - silenceFloor) * (t / 0.04)
            } else {
                amplitude = 0.2 * pow(silenceFloor / 0.2, (t - 0.04) / (duration - 0.04))
            }

            out[n] = Float(Waveform.sine.sample(phase: phase, dt: dt) * amplitude)

            phase += dt
            if phase >= 1 { phase -= 1 }
        }

        // The landing thud, right as the fanfare starts.
        let thud = renderBlip(
            frequency: 220, duration: 0.12, waveform: .square, peak: 0.16, sweepTo: 150,
            sampleRate: sampleRate)
        mix(thud, into: &out, at: duration * 0.9, sampleRate: sampleRate)

        return clamped(out)
    }
}
