import Testing

@testable import MarmorEngine

@Suite("weightedRandomColor")
struct WeightedRandomColorTests {

    @Test("every color remains reachable on an empty board")
    func everyColorReachable() {
        let board = Board()
        var rng = SeededGenerator(seed: 1)
        var seen = Set<ColorIndex>()
        for _ in 0..<2000 { seen.insert(board.weightedRandomColor(using: &rng)) }
        #expect(seen.count == Marmor.colors)
    }

    @Test("is biased toward colors already heavily present on the board")
    func biasedTowardPresentColors() {
        var board = Board()
        // Flood the board with color 2, leaving a single cell for color 6.
        for r in 0..<Marmor.size {
            for c in 0..<Marmor.size { board[r, c] = 2 }
        }
        board[0, 0] = 6

        var rng = SeededGenerator(seed: 2)
        var color2 = 0
        var color6 = 0
        for _ in 0..<2000 {
            switch board.weightedRandomColor(using: &rng) {
            case 2: color2 += 1
            case 6: color6 += 1
            default: break
            }
        }

        // Color 2 dominates the board, so it should be picked dramatically
        // more often than color 6's single occurrence.
        #expect(color2 > color6 * 10)
    }

    @Test("no color starves when none dominates")
    func uniformOnEmptyBoard() {
        let board = Board()
        var rng = SeededGenerator(seed: 3)
        var counts = Array(repeating: 0, count: Marmor.colors)
        for _ in 0..<7000 { counts[board.weightedRandomColor(using: &rng)] += 1 }
        #expect(counts.allSatisfy { $0 > 0 })
    }

    @Test("always returns a valid color index")
    func alwaysInRange() {
        var board = Board()
        board.place([(0, 0), (0, 1), (5, 5)], 4)
        var rng = SeededGenerator(seed: 4)
        for _ in 0..<1000 {
            let color = board.weightedRandomColor(using: &rng)
            #expect(color >= 0 && color < Marmor.colors)
        }
    }

    @Test("never returns a color outside the level's range")
    func respectsColorCount() {
        var board = Board()
        // A color from outside the range already sitting on the board (as
        // after a level change) must not drag the picker past `colorCount`.
        board.place([(0, 0), (0, 1), (0, 2), (0, 3)], 6)
        var rng = SeededGenerator(seed: 5)
        for _ in 0..<500 {
            let color = board.weightedRandomColor(colorCount: 5, using: &rng)
            #expect(color >= 0 && color < 5)
        }
    }

    @Test("affinity 0 ignores the board entirely, unlike affinity 1")
    func affinityDial() {
        var board = Board()
        // 40 marbles of color 0 — at affinity 1 that dominates the weighting;
        // at affinity 0 it should count for nothing.
        for r in 0..<5 {
            for c in 0..<8 { board[r, c] = 0 }
        }

        let runs = 3000
        var rng = SeededGenerator(seed: 6)
        var biased = 0
        var flat = 0
        for _ in 0..<runs {
            if board.weightedRandomColor(affinity: 1, using: &rng) == 0 { biased += 1 }
            if board.weightedRandomColor(affinity: 0, using: &rng) == 0 { flat += 1 }
        }

        // Asserted against the formula rather than hard-coded shares, which
        // would silently encode whatever `colorSmoothing` happens to be.
        let expectedBiased = (40 + colorSmoothing) / (40 + Double(Marmor.colors) * colorSmoothing)
        let expectedFlat = 1 / Double(Marmor.colors)
        #expect(abs(Double(biased) / Double(runs) - expectedBiased) < 0.08)
        #expect(abs(Double(flat) / Double(runs) - expectedFlat) < 0.05)
        // The point of the dial: clustering must be much stronger at 1 than 0.
        #expect(biased > flat * 3)
    }

    @Test("an absent color keeps a usable chance on a busy board")
    func absentColorStaysReachable() {
        // The bug this guards: with too small a smoothing constant, a color
        // that falls behind effectively never returns. On a realistic
        // 47-marble board an absent color must stay well above ~1 in 50 per
        // spawn, or it takes ~18 turns to reappear and the board looks stuck
        // on three colors.
        var board = Board()
        var placed = 0
        for r in 0..<Marmor.size {
            for c in 0..<Marmor.size where placed < 47 {
                board[r, c] = placed % 3  // three colors hog the board
                placed += 1
            }
        }

        let runs = 20_000
        var rng = SeededGenerator(seed: 7)
        var absent = 0
        for _ in 0..<runs {
            if board.weightedRandomColor(using: &rng) == 7 { absent += 1 }
        }
        #expect(Double(absent) / Double(runs) > 0.03)
    }
}

@Suite("findTopThreats")
struct FindTopThreatsTests {

    /// A run of four color-1 marbles at (4,2)...(4,5) — one short of clearing,
    /// completable at either (4,1) or (4,6).
    private func nearlyCompleteRow() -> Board {
        var board = Board()
        board.place([(4, 2), (4, 3), (4, 4), (4, 5)], 1)
        return board
    }

    @Test("finds the cell that would complete a near-full line, sorted first")
    func topThreatIsTheCompletingCell() throws {
        let threats = nearlyCompleteRow().findTopThreats(minLength: 3)
        let top = try #require(threats.first)
        #expect(top.length == 5)
        #expect(top.color == 1)
        #expect(top.cell.r == 4)
        // Both (4,1) and (4,6) complete the line; the tie breaks on column, so
        // the ordering is deterministic rather than sort-implementation defined.
        #expect(top.cell.c == 1)
    }

    @Test("both completing cells are reported")
    func bothCompletingCellsFound() {
        let threats = nearlyCompleteRow().findTopThreats(minLength: 3)
        let completing = threats.filter { $0.length == 5 && $0.color == 1 }
        #expect(Set(completing.map(\.cell)) == [Cell(r: 4, c: 1), Cell(r: 4, c: 6)])
    }

    @Test("results are sorted by descending urgency")
    func sortedByLength() {
        let threats = nearlyCompleteRow().findTopThreats(minLength: 3)
        #expect(zip(threats, threats.dropFirst()).allSatisfy { $0.0.length >= $0.1.length })
    }

    @Test("ignores runs shorter than minLength")
    func ignoresShortRuns() {
        var board = Board()
        board.place([(0, 0)], 4)  // a lone marble — any neighbor fill reaches only 2
        #expect(!board.findTopThreats(minLength: 3).contains { $0.color == 4 })
    }

    @Test("empty board has no threats")
    func emptyBoard() {
        #expect(Board().findTopThreats(minLength: 3).isEmpty)
    }
}

@Suite("assignSpawnCells")
struct AssignSpawnCellsTests {

    private func nearlyCompleteRow() -> Board {
        var board = Board()
        board.place([(4, 2), (4, 3), (4, 4), (4, 5)], 1)
        return board
    }

    @Test("blocks the player's most advanced line with a mismatched color")
    func blocksThreat() {
        var rng = SeededGenerator(seed: 10)
        let result = nearlyCompleteRow().assignSpawnCells(colors: [2], using: &rng)
        #expect(result.blocked)
        #expect(result.cells == [Cell(r: 4, c: 1)])
    }

    @Test("never hands the player the finishing color on their own threat cell")
    func neverCompletesThePlayersLine() {
        // If the only color available IS the threatened color, "blocking" with
        // it would finish the line for the player, so it must fall back to a
        // non-targeted cell. Swept across seeds so this is a real assertion
        // rather than one lucky draw.
        let board = nearlyCompleteRow()
        for seed in 0..<200 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let result = board.assignSpawnCells(colors: [1], using: &rng)
            #expect(!result.blocked)
            #expect(result.cells.count == 1)
            #expect(board[result.cells[0]] == nil)
        }
    }

    @Test("never returns duplicate or occupied cells")
    func noDuplicatesOrOccupied() {
        var board = nearlyCompleteRow()
        board.place([(0, 0), (0, 1), (0, 2)], 3)
        var rng = SeededGenerator(seed: 11)
        let cells = board.assignSpawnCells(colors: [2, 4, 5, 6], using: &rng).cells
        #expect(Set(cells).count == cells.count)
        #expect(cells.allSatisfy { board[$0] == nil })
    }

    @Test("caps output at however many empty cells remain")
    func capsAtRemainingSpace() {
        var board = Board()
        for r in 0..<Marmor.size {
            for c in 0..<Marmor.size where !(r == 0 && (c == 0 || c == 1)) {
                board[r, c] = 0
            }
        }
        // Only 2 empty cells exist; asking for 5 should yield at most 2.
        var rng = SeededGenerator(seed: 12)
        #expect(board.assignSpawnCells(colors: [1, 1, 1, 1, 1], using: &rng).cells.count == 2)
    }

    @Test("a full board yields no spawns")
    func fullBoard() {
        var board = Board()
        for r in 0..<Marmor.size {
            for c in 0..<Marmor.size { board[r, c] = 0 }
        }
        var rng = SeededGenerator(seed: 13)
        let result = board.assignSpawnCells(colors: [1, 2, 3], using: &rng)
        #expect(result.cells.isEmpty)
        #expect(!result.blocked)
    }

    @Test("enableBlocking = false never blocks, even with an obvious threat")
    func blockingDisabled() {
        var rng = SeededGenerator(seed: 14)
        let result = nearlyCompleteRow()
            .assignSpawnCells(colors: [2], enableBlocking: false, using: &rng)
        #expect(!result.blocked)
    }

    @Test("a threat in a color outside the level's range is not blocked")
    func ignoresOutOfRangeThreats() {
        var board = Board()
        // Color 6 exists on the board but this level only plays colors 0-4, so
        // the threat scan must not see it and must not aim a spawn at it.
        board.place([(4, 2), (4, 3), (4, 4), (4, 5)], 6)
        var rng = SeededGenerator(seed: 15)
        let result = board.assignSpawnCells(colors: [2], colorCount: 5, using: &rng)
        #expect(!result.blocked)
    }

    @Test("placements are always empty, in-bounds and distinct across many seeds")
    func robustAcrossSeeds() {
        var board = nearlyCompleteRow()
        board.place([(0, 0), (1, 1), (7, 7)], 3)
        for seed in 0..<300 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let cells = board.assignSpawnCells(colors: [2, 3, 5], using: &rng).cells
            #expect(cells.count == 3)
            #expect(Set(cells).count == 3)
            for cell in cells {
                #expect(Board.inBounds(cell.r, cell.c))
                #expect(board[cell] == nil)
            }
        }
    }
}
