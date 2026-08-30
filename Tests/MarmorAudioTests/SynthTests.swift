import Foundation
import Testing

@testable import MarmorAudio

/// Reused from the engine's test support — a seeded SplitMix64, so noise
/// bursts are reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Counts sign changes — a cheap proxy for frequency.
func signChanges(_ samples: ArraySlice<Float>) -> Int {
    var changes = 0
    for (a, b) in zip(samples, samples.dropFirst()) where (a < 0) != (b < 0) {
        changes += 1
    }
    return changes
}

@Suite("Envelope")
struct EnvelopeTests {

    let envelope = Envelope(attack: 0.01, decay: 0.1, peak: 0.5)

    @Test("starts silent")
    func startsSilent() {
        #expect(envelope.amplitude(at: 0) == 0)
    }

    @Test("rises linearly to the peak across the attack")
    func linearAttack() {
        #expect(abs(envelope.amplitude(at: 0.005) - 0.25) < 1e-9)
        #expect(abs(envelope.amplitude(at: 0.01) - 0.5) < 1e-9)
    }

    @Test("decays monotonically after the peak")
    func monotonicDecay() {
        let samples = stride(from: 0.01, through: 0.11, by: 0.005).map { envelope.amplitude(at: $0) }
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0.0 > $0.1 })
    }

    @Test("is silent past its total duration")
    func silentAfterEnd() {
        #expect(envelope.amplitude(at: 0.2) == 0)
        #expect(abs(envelope.duration - 0.11) < 1e-9)
    }
}

@Suite("Waveform")
struct WaveformTests {

    @Test("stays in range across a full cycle", arguments: [Waveform.sine, .square, .triangle, .sawtooth])
    func inRange(waveform: Waveform) {
        let dt = 440.0 / defaultSampleRate
        for i in 0..<1000 {
            let value = waveform.sample(phase: Double(i) / 1000, dt: dt)
            #expect(value.isFinite)
            // PolyBLEP overshoots slightly at the discontinuities; well inside
            // the headroom the envelope peaks leave.
            #expect(abs(value) <= 1.1)
        }
    }

    @Test("sine is symmetric about the half cycle")
    func sineSymmetry() {
        let dt = 440.0 / defaultSampleRate
        #expect(abs(Waveform.sine.sample(phase: 0.25, dt: dt) - 1) < 1e-9)
        #expect(abs(Waveform.sine.sample(phase: 0.75, dt: dt) + 1) < 1e-9)
    }

    @Test("square changes sign at the half cycle")
    func squarePolarity() {
        let dt = 440.0 / defaultSampleRate
        #expect(Waveform.square.sample(phase: 0.25, dt: dt) > 0)
        #expect(Waveform.square.sample(phase: 0.75, dt: dt) < 0)
    }

    @Test("triangle peaks mid-cycle and troughs at the edges")
    func trianglePeaks() {
        let dt = 440.0 / defaultSampleRate
        #expect(abs(Waveform.triangle.sample(phase: 0.5, dt: dt) - 1) < 1e-9)
        #expect(abs(Waveform.triangle.sample(phase: 0, dt: dt) + 1) < 1e-9)
    }
}

@Suite("Biquad")
struct BiquadTests {

    /// Runs a sine of `frequency` through `filter` and returns its RMS.
    func rms(frequency: Double, through filter: inout Biquad) -> Double {
        let count = 4410
        var sum = 0.0
        for i in 0..<count {
            let input = sin(2 * .pi * frequency * Double(i) / defaultSampleRate)
            let output = filter.process(input)
            // Skip the settling transient.
            if i > 500 { sum += output * output }
        }
        return (sum / Double(count - 500)).squareRoot()
    }

    @Test("lowpass attenuates high frequencies more than low")
    func lowpass() {
        var lowFilter = Biquad(.lowpass, frequency: 500, sampleRate: defaultSampleRate)
        var highFilter = Biquad(.lowpass, frequency: 500, sampleRate: defaultSampleRate)
        let passed = rms(frequency: 100, through: &lowFilter)
        let rejected = rms(frequency: 5000, through: &highFilter)
        #expect(passed > rejected)
    }

    @Test("highpass attenuates low frequencies more than high")
    func highpass() {
        var lowFilter = Biquad(.highpass, frequency: 2200, sampleRate: defaultSampleRate)
        var highFilter = Biquad(.highpass, frequency: 2200, sampleRate: defaultSampleRate)
        let rejected = rms(frequency: 200, through: &lowFilter)
        let passed = rms(frequency: 8000, through: &highFilter)
        #expect(passed > rejected)
    }

    @Test("output stays finite")
    func staysFinite() {
        var filter = Biquad(.lowpass, frequency: 500, sampleRate: defaultSampleRate)
        var allFinite = true
        for i in 0..<10_000 where !filter.process(sin(Double(i))).isFinite {
            allFinite = false
        }
        #expect(allFinite)
    }
}

@Suite("renderBlip")
struct RenderBlipTests {

    @Test("buffer length covers attack plus decay")
    func length() {
        let blip = renderBlip(frequency: 440, duration: 0.09)
        // Tolerant by a sample: 0.005 + 0.09 and the literal 0.095 need not
        // round identically in binary floating point.
        #expect(abs(blip.count - sampleCount(0.095, sampleRate: defaultSampleRate)) <= 1)
    }

    @Test("starts and ends near silence")
    func fadesInAndOut() {
        let blip = renderBlip(frequency: 440, duration: 0.09, peak: 0.5)
        #expect(abs(blip.first ?? 1) < 0.01)
        #expect(abs(blip.last ?? 1) < 0.01)
    }

    @Test("never exceeds the requested peak by more than the polyBLEP overshoot")
    func respectsPeak() {
        let blip = renderBlip(frequency: 440, duration: 0.09, waveform: .square, peak: 0.18)
        #expect(blip.allSatisfy { $0.isFinite })
        #expect(blip.allSatisfy { abs($0) <= 0.18 * 1.15 })
    }

    @Test("a downward sweep lowers the pitch over the sound")
    func sweepLowersPitch() {
        let blip = renderBlip(
            frequency: 800, duration: 0.4, waveform: .square, peak: 0.5, sweepTo: 200)
        let window = blip.count / 10
        let start = signChanges(blip[0..<window])
        let end = signChanges(blip[(blip.count - window)..<blip.count])
        #expect(start > end)
    }

    @Test("no sweep holds a steady pitch")
    func steadyWithoutSweep() {
        let blip = renderBlip(frequency: 800, duration: 0.4, waveform: .square, peak: 0.5)
        let window = blip.count / 10
        let start = signChanges(blip[0..<window])
        let end = signChanges(blip[(blip.count - window)..<blip.count])
        #expect(abs(start - end) <= 2)
    }
}

@Suite("renderNoiseBurst")
struct RenderNoiseBurstTests {

    @Test("is reproducible for a given seed")
    func reproducible() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 1)
        let first = renderNoiseBurst(using: &a)
        let second = renderNoiseBurst(using: &b)
        #expect(first == second)
    }

    @Test("differs between seeds")
    func differsBySeed() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        let first = renderNoiseBurst(using: &a)
        let second = renderNoiseBurst(using: &b)
        #expect(first != second)
    }

    @Test("has energy and stays finite")
    func hasEnergy() {
        var rng = SeededGenerator(seed: 3)
        let burst = renderNoiseBurst(peak: 0.12, using: &rng)
        #expect(burst.allSatisfy(\.isFinite))
        #expect(burst.contains { $0.magnitude > 0.001 })
    }
}
