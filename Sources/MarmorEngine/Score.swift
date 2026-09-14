/// Ranking rules for the Hall of Pretenders. Pure and dependency-free (apart
/// from `levelCount`) so the ordering can be unit-tested, and so the exact
/// same comparison can later run server-side.
///
/// Port of `src/game/score.ts`. The free functions there become properties and
/// methods here, which is the Swift shape of the same logic —
/// `progressOf(entry)` reads better as `entry.progress`.

/// One completed run. `score` is what the player sees; it is deliberately NOT
/// what they're ranked on — see `progress`.
public struct RunEntry: Equatable, Sendable {
    /// Stable per-device id, so a player's row updates instead of duplicating.
    public var id: String
    public var name: String
    /// Rounds fully cleared this run, `0...levelCount`.
    public var roundsCleared: Int
    /// Points banked in the round the run ended in; 0 for a finished run.
    public var partialPoints: Int
    /// Marble moves across the whole run — the skill axis. Fewer is better.
    public var moves: Int
    /// Total Pretender points, overshoot included. Display only.
    public var score: Int
    /// Epoch milliseconds, for tie-breaking and "when".
    public var at: Int

    public init(
        id: String,
        name: String,
        roundsCleared: Int,
        partialPoints: Int,
        moves: Int,
        score: Int,
        at: Int
    ) {
        self.id = id
        self.name = name
        self.roundsCleared = roundsCleared
        self.partialPoints = partialPoints
        self.moves = moves
        self.score = score
        self.at = at
    }
}

/// The score a run that cleared the whole ladder lands on.
public let maxProgress = levelCount * 100

/// Move counts above this are capped, so an absurd value can't wrap the sort
/// key into a better position.
let maxMoves = 99_999

extension RunEntry {

    public var isFinisher: Bool {
        roundsCleared >= levelCount
    }

    /// How far the run got, with last-clear luck removed.
    ///
    /// A round ends the moment the score crosses the King's 100, so a round's
    /// raw points are `100 + overshoot`, and the overshoot is just however
    /// long the final clear happened to be. Ranking on raw points would
    /// therefore sort finishers by luck. Counting a flat 100 per cleared round
    /// plus whatever was banked in the round they died in strips that out:
    /// every finisher lands on exactly `maxProgress` and is separated only by
    /// `moves`, while players who fell short still rank smoothly by how deep
    /// they got.
    public var progress: Int {
        let rounds = clamp(roundsCleared, 0, levelCount)
        // Clamped below 100 by construction — 100 would have cleared the round
        // — but a corrupt or hand-edited entry shouldn't buy a free round.
        let partial = rounds >= levelCount ? 0 : clamp(partialPoints, 0, 99)
        return rounds * 100 + partial
    }

    /// Packs (progress desc, moves asc) into one ascending number, so a Redis
    /// sorted set can hold the whole ordering in its single float score.
    ///
    /// The TypeScript version has to stay inside float64's exact-integer range
    /// for that; Swift's `Int` is 64-bit and exact throughout, so the ceiling
    /// only matters for the wire format.
    public var sortKey: Int {
        progress * 100_000 + (maxMoves - clamp(moves, 0, maxMoves))
    }

    /// "8/8" for a finished run, otherwise the round it ended in and the
    /// points banked there ("R6 · 45").
    public var reachedLabel: String {
        if isFinisher { return "\(levelCount)/\(levelCount)" }
        return "R\(roundsCleared + 1) · \(partialPoints)"
    }

    /// True when `self` is a better run than `other` — used to keep one row
    /// per player rather than a wall of their attempts.
    public func isBetter(than other: RunEntry) -> Bool {
        sortKey > other.sortKey
    }

    /// Best-first ordering. Higher progress wins; ties go to fewer moves; then
    /// to whoever got there first, so an existing row is never displaced by an
    /// identical later one.
    ///
    /// The final tie-break on `id` has no counterpart in the TypeScript, which
    /// leans on JavaScript's stable sort to leave equal entries in input
    /// order. Swift's sort is not stable, so the order is made total here
    /// instead — otherwise two runs identical down to the timestamp could
    /// swap places between launches.
    public static func ranksBefore(_ a: RunEntry, _ b: RunEntry) -> Bool {
        if a.sortKey != b.sortKey { return a.sortKey > b.sortKey }
        if a.at != b.at { return a.at < b.at }
        return a.id < b.id
    }
}

public func rankEntries(_ entries: [RunEntry]) -> [RunEntry] {
    entries.sorted(by: RunEntry.ranksBefore)
}

private func clamp(_ n: Int, _ lo: Int, _ hi: Int) -> Int {
    min(max(n, lo), hi)
}
