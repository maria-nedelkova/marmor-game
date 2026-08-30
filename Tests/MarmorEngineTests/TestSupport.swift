import MarmorEngine

/// SplitMix64 — a small, fast, well-distributed PRNG.
///
/// Every randomized test seeds one of these instead of using the system
/// generator, so a failure can be reproduced by rerunning with the same seed.
/// (The TypeScript suite fuzzes against an unseeded `Math.random`, which means
/// its failures are not reproducible.)
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

extension Board {
    /// Fills `cells` with `color`. Mirrors the `place` helper in engine.test.ts.
    mutating func place(_ cells: [(Int, Int)], _ color: ColorIndex) {
        for (r, c) in cells { self[r, c] = color }
    }

    /// A board with a solid wall of `color` down the given column.
    static func walledAtColumn(_ c: Int, color: ColorIndex = 1) -> Board {
        var board = Board()
        for r in 0..<Marmor.size { board[r, c] = color }
        return board
    }
}
