import Foundation

/// Oscillator shapes, matching Web Audio's `OscillatorType` names so the sound
/// definitions read the same as `src/audio/sound.ts`.
public enum Waveform: Sendable {
    case sine
    case square
    case triangle
    case sawtooth
}

/// PolyBLEP — a correction term that rounds off the discontinuities in square
/// and sawtooth waves, which otherwise alias badly at high frequencies.
///
/// Web Audio's oscillators are band-limited; a naive `phase < 0.5 ? 1 : -1`
/// is not, and the difference is audible on the brighter blips (the win
/// fanfare tops out at 1047 Hz). This is the cheap standard fix.
///
/// - Parameters:
///   - t: normalized phase in `0..<1`
///   - dt: phase increment per sample, i.e. `frequency / sampleRate`
@inline(__always)
func polyBLEP(_ t: Double, _ dt: Double) -> Double {
    if t < dt {
        let x = t / dt
        return x + x - x * x - 1
    }
    if t > 1 - dt {
        let x = (t - 1) / dt
        return x * x + x + x + 1
    }
    return 0
}

extension Waveform {
    /// One sample of this waveform at normalized `phase`, with `dt` the
    /// per-sample phase increment (needed for anti-aliasing).
    @inline(__always)
    func sample(phase t: Double, dt: Double) -> Double {
        switch self {
        case .sine:
            return sin(2 * .pi * t)

        case .square:
            var value = t < 0.5 ? 1.0 : -1.0
            value += polyBLEP(t, dt)
            value -= polyBLEP((t + 0.5).truncatingRemainder(dividingBy: 1), dt)
            return value

        case .sawtooth:
            return (2 * t - 1) - polyBLEP(t, dt)

        case .triangle:
            // Harmonics fall off as 1/n², so aliasing is negligible and the
            // naive piecewise form is fine.
            return t < 0.5 ? 4 * t - 1 : 3 - 4 * t
        }
    }
}
