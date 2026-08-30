import Foundation

/// A two-pole filter using the standard RBJ cookbook coefficients — the same
/// design Web Audio's `BiquadFilterNode` uses, so `filter.type = "highpass"`
/// and friends port across directly.
///
/// `Q` defaults to 1, matching Web Audio's default.
struct Biquad {
    private var b0: Double = 1
    private var b1: Double = 0
    private var b2: Double = 0
    private var a1: Double = 0
    private var a2: Double = 0

    // Direct Form I state.
    private var x1: Double = 0
    private var x2: Double = 0
    private var y1: Double = 0
    private var y2: Double = 0

    enum Kind {
        case lowpass
        case highpass
    }

    init(_ kind: Kind, frequency: Double, sampleRate: Double, q: Double = 1) {
        let w0 = 2 * .pi * frequency / sampleRate
        let cosW0 = cos(w0)
        let alpha = sin(w0) / (2 * q)

        let a0: Double
        switch kind {
        case .lowpass:
            b0 = (1 - cosW0) / 2
            b1 = 1 - cosW0
            b2 = (1 - cosW0) / 2
        case .highpass:
            b0 = (1 + cosW0) / 2
            b1 = -(1 + cosW0)
            b2 = (1 + cosW0) / 2
        }
        a0 = 1 + alpha
        a1 = -2 * cosW0
        a2 = 1 - alpha

        // Normalize so the difference equation drops a0.
        b0 /= a0
        b1 /= a0
        b2 /= a0
        a1 /= a0
        a2 /= a0
    }

    mutating func process(_ x0: Double) -> Double {
        let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x0
        y2 = y1
        y1 = y0
        return y0
    }
}
