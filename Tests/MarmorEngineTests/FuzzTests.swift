import Testing

@testable import MarmorEngine

@Suite("fuzz")
struct FuzzTests {

    /// Plays 10,000 random legal moves and asserts the board never enters an
    /// impossible state. Seeded, so any failure is reproducible from the seed
    /// reported in the test name.
    @Test("random legal moves never crash or corrupt the board", arguments: [1, 7, 42] as [UInt64])
    func randomLegalMoves(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        var board = Board()

        // Seed with 5 marbles.
        for _ in 0..<5 {
            let free = board.emptyCells()
            board[free[Int.random(in: 0..<free.count, using: &rng)]] =
                randomColor(using: &rng)
        }

        for _ in 0..<10_000 {
            var occupied: [Cell] = []
            var free: [Cell] = []
            for r in 0..<Marmor.size {
                for c in 0..<Marmor.size {
                    let cell = Cell(r: r, c: c)
                    if board[cell] == nil { free.append(cell) } else { occupied.append(cell) }
                }
            }
            if occupied.isEmpty || free.isEmpty { break }

            let from = occupied[Int.random(in: 0..<occupied.count, using: &rng)]
            let to = free[Int.random(in: 0..<free.count, using: &rng)]
            guard let path = board.findPath(from: from, to: to) else { continue }

            // Any path the engine hands back must actually be walkable.
            #expect(path.first == from)
            #expect(path.last == to)
            for (a, b) in zip(path, path.dropFirst()) {
                #expect(abs(a.r - b.r) + abs(a.c - b.c) == 1)
            }
            for step in path.dropFirst() {
                #expect(board[step] == nil)
            }

            let color = board[from]
            board[from] = nil
            board[to] = color

            let matches = board.findLinesThrough(to)
            if matches.isEmpty {
                // Round 1's spawn count — the classic three a turn.
                let colors = board.weightedRandomColors(levels[0].spawnCount, using: &rng)
                let spawn = board.assignSpawnCells(colors: colors, using: &rng)
                #expect(spawn.cells.count == Set(spawn.cells).count)
                for (cell, color) in zip(spawn.cells, colors) {
                    #expect(board[cell] == nil)
                    board[cell] = color
                }
            } else {
                #expect(matches.count >= Marmor.lineMin)
                for cell in matches { board[cell] = nil }
            }

            // Invariants: the marble count stays in range, and every marble on
            // the board is a color the palette actually has.
            #expect(board.marbleCount >= 0)
            #expect(board.marbleCount <= Marmor.size * Marmor.size)
            for r in 0..<Marmor.size {
                for c in 0..<Marmor.size {
                    if let color = board[r, c] {
                        #expect(color >= 0 && color < Marmor.colors)
                    }
                }
            }
        }
    }

    /// The pathfinder and the flood fill must agree: a destination is
    /// reachable if and only if a path to it exists.
    @Test("findPath and reachableFrom agree", arguments: [3, 99] as [UInt64])
    func pathAndReachabilityAgree(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)

        for _ in 0..<200 {
            var board = Board()
            // Scatter a random number of marbles.
            for _ in 0..<Int.random(in: 0..<60, using: &rng) {
                let free = board.emptyCells()
                if free.isEmpty { break }
                board[free[Int.random(in: 0..<free.count, using: &rng)]] = randomColor(using: &rng)
            }

            let occupied = (0..<Marmor.size).flatMap { r in
                (0..<Marmor.size).map { Cell(r: r, c: $0) }
            }.filter { board[$0] != nil }
            guard let from = occupied.randomElement(using: &rng) else { continue }

            let reachable = Set(board.reachableFrom(from))
            for cell in board.emptyCells() {
                #expect((board.findPath(from: from, to: cell) != nil) == reachable.contains(cell))
            }
        }
    }
}
