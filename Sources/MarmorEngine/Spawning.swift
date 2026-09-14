/// Everything that depends on randomness: what colors spawn, and where they
/// land. Port of the spawner half of `src/game/engine.ts`.
///
/// The TypeScript version calls a module-level `rng.random()` and its tests
/// swap that object's function out. Swift has no equivalent, so the generator
/// is threaded through as an `inout` parameter instead. Every function has a
/// convenience overload that supplies the system generator, so game code reads
/// the same as before while tests stay reproducible.
///
/// `colorCount` throughout is how many colors are in play this level (see
/// `LevelConfig.colors`); it defaults to the full palette so the engine is
/// still usable — and testable — without a level in hand.

// MARK: - Color choice

/// A uniformly random color from the first `colorCount` of the palette.
public func randomColor<G: RandomNumberGenerator>(
    colorCount: Int = Marmor.colors,
    using rng: inout G
) -> ColorIndex {
    Int.random(in: 0..<colorCount, using: &rng)
}

public func randomColor(colorCount: Int = Marmor.colors) -> ColorIndex {
    var rng = SystemRandomNumberGenerator()
    return randomColor(colorCount: colorCount, using: &rng)
}

public func randomColors<G: RandomNumberGenerator>(
    _ n: Int,
    colorCount: Int = Marmor.colors,
    using rng: inout G
) -> [ColorIndex] {
    (0..<n).map { _ in randomColor(colorCount: colorCount, using: &rng) }
}

/// Additive smoothing: every color's weight starts here before its on-board
/// count is added, so this alone sets the floor probability for a color that
/// isn't on the board at all.
///
/// It was 1, which is far too low once the board fills. On a realistic
/// 47-marble board with 8 colors that floor is 1/55 — about 1.8% per spawn, or
/// an expected 18 turns before an absent color shows up at all. At 3 the floor
/// is ~4.2%, or roughly 8 turns, which keeps the board's palette moving
/// without flattening the clustering that makes lines buildable in the first
/// place.
public let colorSmoothing: Double = 3

extension Board {

    /// Picks a color weighted toward colors already present on the board — the
    /// more of a color already on the table, the likelier it spawns again,
    /// which makes lines easier to complete (and to run into by accident).
    /// `colorSmoothing` keeps every color reachable even when absent.
    ///
    /// `affinity` scales how much that already-on-the-board bias counts: 1 is
    /// the classic helpful clustering, 0 flattens it to uniform random. Late
    /// levels turn it down to make runs stall without changing anything the
    /// player can see.
    public func weightedRandomColor<G: RandomNumberGenerator>(
        colorCount: Int = Marmor.colors,
        affinity: Double = 1,
        using rng: inout G
    ) -> ColorIndex {
        let weights = colorCounts(colorCount: colorCount).map {
            Double($0) * affinity + colorSmoothing
        }
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }

        var roll = Double.random(in: 0..<total, using: &rng)
        for (color, weight) in weights.enumerated() {
            roll -= weight
            if roll < 0 { return color }
        }
        return weights.count - 1
    }

    public func weightedRandomColor(
        colorCount: Int = Marmor.colors,
        affinity: Double = 1
    ) -> ColorIndex {
        var rng = SystemRandomNumberGenerator()
        return weightedRandomColor(colorCount: colorCount, affinity: affinity, using: &rng)
    }

    public func weightedRandomColors<G: RandomNumberGenerator>(
        _ n: Int,
        colorCount: Int = Marmor.colors,
        affinity: Double = 1,
        using rng: inout G
    ) -> [ColorIndex] {
        (0..<n).map { _ in
            weightedRandomColor(colorCount: colorCount, affinity: affinity, using: &rng)
        }
    }

    public func weightedRandomColors(
        _ n: Int,
        colorCount: Int = Marmor.colors,
        affinity: Double = 1
    ) -> [ColorIndex] {
        var rng = SystemRandomNumberGenerator()
        return weightedRandomColors(n, colorCount: colorCount, affinity: affinity, using: &rng)
    }
}

// MARK: - Threat detection

/// An empty cell that would extend a run if filled with a particular color.
public struct CellThreat: Equatable, Sendable {
    public var cell: Cell
    public var color: ColorIndex
    /// Resulting run length if this cell were filled with `color`.
    public var length: Int

    public init(cell: Cell, color: ColorIndex, length: Int) {
        self.cell = cell
        self.color = color
        self.length = length
    }
}

extension Board {

    /// Scans every empty cell for near-complete lines — cells that, if filled
    /// with a given color, would extend an existing run to at least
    /// `minLength`. Sorted most urgent (longest resulting run) first. This is
    /// what the spawner uses to find the player's in-progress lines worth
    /// blocking.
    ///
    /// Ties break on position then color. The TypeScript version relies on
    /// JavaScript's stable sort for this; Swift's `sorted(by:)` makes no such
    /// guarantee, so the ordering is made total explicitly — otherwise which
    /// line the spawner blocks could vary between runs on an equal-length tie.
    public func findTopThreats(
        minLength: Int = 3,
        colorCount: Int = Marmor.colors
    ) -> [CellThreat] {
        var threats: [CellThreat] = []
        for r in 0..<Marmor.size {
            for c in 0..<Marmor.size where self[r, c] == nil {
                let cell = Cell(r: r, c: c)
                for color in 0..<colorCount {
                    let length = longestRunThrough(cell, color: color)
                    if length >= minLength {
                        threats.append(CellThreat(cell: cell, color: color, length: length))
                    }
                }
            }
        }
        return threats.sorted { a, b in
            if a.length != b.length { return a.length > b.length }
            if a.cell.r != b.cell.r { return a.cell.r < b.cell.r }
            if a.cell.c != b.cell.c { return a.cell.c < b.cell.c }
            return a.color < b.color
        }
    }
}

// MARK: - Spawn placement

public struct SpawnAssignment: Equatable, Sendable {
    public var cells: [Cell]
    /// True if at least one of `cells` was chosen specifically to block a
    /// near-complete line.
    public var blocked: Bool

    public init(cells: [Cell], blocked: Bool) {
        self.cells = cells
        self.blocked = blocked
    }
}

extension Board {

    /// Assigns each of `colors` (already decided, e.g. from the next-up queue)
    /// to an empty cell. When `enableBlocking` is on, it prefers the board's
    /// most urgent near-complete lines, placing a *different* color there to
    /// block, falling back to a random empty cell when no block is available
    /// or useful for that color.
    ///
    /// This is the "AI" behind the difficulty: it doesn't change *what* colors
    /// spawn, only *where* they land. The caller decides *when* blocking is
    /// allowed (each level has its own per-turn chance) via `enableBlocking`.
    ///
    /// - Parameters:
    ///   - minBlockLength: how long an existing run must be before blocking it
    ///     is worthwhile.
    ///   - enableBlocking: whether blocking is permitted at all on this spawn.
    ///   - colorCount: colors in play this level — bounds the threat scan.
    public func assignSpawnCells<G: RandomNumberGenerator>(
        colors: [ColorIndex],
        minBlockLength: Int = 3,
        enableBlocking: Bool = true,
        colorCount: Int = Marmor.colors,
        using rng: inout G
    ) -> SpawnAssignment {
        var remainingFree = emptyCells()
        let toPlace = min(colors.count, remainingFree.count)
        guard toPlace > 0 else { return SpawnAssignment(cells: [], blocked: false) }

        let threats =
            enableBlocking
            ? findTopThreats(minLength: minBlockLength, colorCount: colorCount) : []
        var used = Set<Cell>()
        var assigned: [Cell] = []
        var blocked = false

        for i in 0..<toPlace {
            let color = colors[i]
            // Never block with the color the player is waiting for — placing
            // it on their threat cell would finish the line *for* them.
            let blocker = threats.first { $0.color != color && !used.contains($0.cell) }

            // The blocker's cell should always still be free (anything already
            // assigned is in `used`), but fall back to a random cell rather
            // than trust that — the TypeScript original's `findIndex`/`splice`
            // pair would silently grab the last free cell if it ever missed.
            let blockerIndex = blocker.flatMap { remainingFree.firstIndex(of: $0.cell) }
            let index = blockerIndex ?? Int.random(in: 0..<remainingFree.count, using: &rng)

            let cell = remainingFree.remove(at: index)
            used.insert(cell)
            assigned.append(cell)
            if blockerIndex != nil { blocked = true }
        }

        return SpawnAssignment(cells: assigned, blocked: blocked)
    }

    public func assignSpawnCells(
        colors: [ColorIndex],
        minBlockLength: Int = 3,
        enableBlocking: Bool = true,
        colorCount: Int = Marmor.colors
    ) -> SpawnAssignment {
        var rng = SystemRandomNumberGenerator()
        return assignSpawnCells(
            colors: colors,
            minBlockLength: minBlockLength,
            enableBlocking: enableBlocking,
            colorCount: colorCount,
            using: &rng
        )
    }
}
