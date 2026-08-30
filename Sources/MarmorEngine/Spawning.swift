/// Everything that depends on randomness: what colors spawn, and where they
/// land. Port of the spawner half of `src/game/engine.ts`.
///
/// The TypeScript version calls `Math.random()` directly and its tests
/// monkey-patch the global to pin it down. Swift has no equivalent, so the
/// generator is threaded through as an `inout` parameter instead. Every
/// function has a convenience overload that supplies the system generator, so
/// game code reads the same as before while tests stay reproducible.

// MARK: - Color choice

/// A uniformly random color.
public func randomColor<G: RandomNumberGenerator>(using rng: inout G) -> ColorIndex {
    Int.random(in: 0..<Marmor.colors, using: &rng)
}

public func randomColor() -> ColorIndex {
    var rng = SystemRandomNumberGenerator()
    return randomColor(using: &rng)
}

public func randomColors<G: RandomNumberGenerator>(_ n: Int, using rng: inout G) -> [ColorIndex] {
    (0..<n).map { _ in randomColor(using: &rng) }
}

extension Board {

    /// Picks a color weighted toward colors already present on the board — the
    /// more of a color already on the table, the likelier it spawns again,
    /// which makes lines easier to complete (and to run into by accident). A
    /// +1 smoothing weight keeps every color reachable even when absent.
    public func weightedRandomColor<G: RandomNumberGenerator>(using rng: inout G) -> ColorIndex {
        let weights = colorCounts().map { $0 + 1 }
        let total = weights.reduce(0, +)
        var roll = Int.random(in: 0..<total, using: &rng)
        for (color, weight) in weights.enumerated() {
            roll -= weight
            if roll < 0 { return color }
        }
        return weights.count - 1
    }

    public func weightedRandomColor() -> ColorIndex {
        var rng = SystemRandomNumberGenerator()
        return weightedRandomColor(using: &rng)
    }

    public func weightedRandomColors<G: RandomNumberGenerator>(_ n: Int, using rng: inout G) -> [ColorIndex] {
        (0..<n).map { _ in weightedRandomColor(using: &rng) }
    }

    public func weightedRandomColors(_ n: Int) -> [ColorIndex] {
        var rng = SystemRandomNumberGenerator()
        return weightedRandomColors(n, using: &rng)
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
    public func findTopThreats(minLength: Int = Marmor.blockMinRunLength) -> [CellThreat] {
        var threats: [CellThreat] = []
        for r in 0..<Marmor.size {
            for c in 0..<Marmor.size where self[r, c] == nil {
                let cell = Cell(r: r, c: c)
                for color in 0..<Marmor.colors {
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
    /// allowed via `enableBlocking`.
    public func assignSpawnCells<G: RandomNumberGenerator>(
        colors: [ColorIndex],
        minBlockLength: Int = Marmor.blockMinRunLength,
        enableBlocking: Bool = true,
        using rng: inout G
    ) -> SpawnAssignment {
        var remainingFree = emptyCells()
        let toPlace = min(colors.count, remainingFree.count)
        guard toPlace > 0 else { return SpawnAssignment(cells: [], blocked: false) }

        let threats = enableBlocking ? findTopThreats(minLength: minBlockLength) : []
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
        minBlockLength: Int = Marmor.blockMinRunLength,
        enableBlocking: Bool = true
    ) -> SpawnAssignment {
        var rng = SystemRandomNumberGenerator()
        return assignSpawnCells(
            colors: colors,
            minBlockLength: minBlockLength,
            enableBlocking: enableBlocking,
            using: &rng
        )
    }
}
