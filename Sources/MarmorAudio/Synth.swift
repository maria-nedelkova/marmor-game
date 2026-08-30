import Foundation

/// Synthesis primitives. Everything here is pure — it takes parameters and
/// returns mono `Float` samples in -1...1, with no reference to AVFoundation
/// or any audio device, which is what makes the sound design unit-testable.

public let defaultSampleRate: Double = 44_100

/// Web Audio's `exponentialRampToValueAtTime` can't reach zero, so the web
/// version ramps to 0.0001 instead. Kept identical here so envelope tails
/// decay at the same rate.
let silenceFloor: Double = 0.0001

/// Linear attack up to `peak`, then an exponential decay to silence — the
/// shape `envelopeGain` builds in `src/audio/sound.ts`.
struct Envelope {
    var attack: Double
    var decay: Double
    var peak: Double

    var duration: Double { attack + decay }

    func amplitude(at t: Double) -> Double {
        if t <= 0 { return 0 }
        if t < attack { return peak * (t / attack) }
        let d = t - attack
        if d < decay { return peak * pow(silenceFloor / peak, d / decay) }
        return 0
    }
}

func sampleCount(_ duration: Double, sampleRate: Double) -> Int {
    max(0, Int((duration * sampleRate).rounded()))
}

/// Mixes `source` into `destination` starting at `offset` samples, growing the
/// destination if the source runs past its end.
func mix(_ source: [Float], into destination: inout [Float], atSample offset: Int) {
    let end = offset + source.count
    if destination.count < end {
        destination.append(contentsOf: repeatElement(0, count: end - destination.count))
    }
    for i in 0..<source.count {
        destination[offset + i] += source[i]
    }
}

func mix(_ source: [Float], into destination: inout [Float], at time: Double, sampleRate: Double) {
    mix(source, into: &destination, atSample: sampleCount(time, sampleRate: sampleRate))
}

/// Clamps to -1...1. Web Audio clips at the destination too; this just makes
/// it explicit and keeps the buffer well-formed.
func clamped(_ samples: [Float]) -> [Float] {
    samples.map { min(1, max(-1, $0)) }
}

/// A short oscillator tone with an optional exponential pitch sweep — the
/// `blip` of the web version.
///
/// The sweep runs over `duration` and then holds, matching Web Audio's
/// behavior after a ramp's end time.
func renderBlip(
    frequency: Double,
    duration: Double = 0.09,
    waveform: Waveform = .square,
    peak: Double = 0.18,
    sweepTo: Double? = nil,
    sampleRate: Double = defaultSampleRate
) -> [Float] {
    let envelope = Envelope(attack: 0.005, decay: duration, peak: peak)
    let count = sampleCount(envelope.duration, sampleRate: sampleRate)
    var out = [Float](repeating: 0, count: count)

    var phase = 0.0
    for i in 0..<count {
        let t = Double(i) / sampleRate

        let frequencyNow: Double
        if let sweepTo {
            let progress = min(1, t / duration)
            frequencyNow = frequency * pow(sweepTo / frequency, progress)
        } else {
            frequencyNow = frequency
        }

        let dt = frequencyNow / sampleRate
        out[i] = Float(waveform.sample(phase: phase, dt: dt) * envelope.amplitude(at: t))

        phase += dt
        if phase >= 1 { phase -= 1 }
    }
    return out
}

/// A filtered burst of white noise — the percussive half of `playPlace`.
///
/// Takes its generator by reference for the same reason the game engine does:
/// tests need reproducible output, and Swift has no equivalent of the web
/// version's `Math.random` monkey-patching.
func renderNoiseBurst<G: RandomNumberGenerator>(
    duration: Double = 0.08,
    peak: Double = 0.12,
    filterFrequency: Double = 2200,
    sampleRate: Double = defaultSampleRate,
    using rng: inout G
) -> [Float] {
    let envelope = Envelope(attack: 0.002, decay: duration, peak: peak)
    let count = sampleCount(duration, sampleRate: sampleRate)
    var filter = Biquad(.highpass, frequency: filterFrequency, sampleRate: sampleRate)
    var out = [Float](repeating: 0, count: count)

    for i in 0..<count {
        let t = Double(i) / sampleRate
        let white = Double.random(in: -1...1, using: &rng)
        out[i] = Float(filter.process(white) * envelope.amplitude(at: t))
    }
    return out
}
