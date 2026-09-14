import Testing

@testable import MarmorEngine

@Suite("findLinesThrough")
struct FindLinesThroughTests {

    @Test("horizontal line of exactly 5 clears")
    func horizontalFive() {
        var board = Board()
        board.place([(4, 2), (4, 3), (4, 4), (4, 5), (4, 6)], 1)
        #expect(board.findLinesThrough(Cell(r: 4, c: 4)).count == 5)
    }

    @Test("horizontal line of 4 does not clear")
    func horizontalFour() {
        var board = Board()
        board.place([(4, 2), (4, 3), (4, 4), (4, 5)], 1)
        #expect(board.findLinesThrough(Cell(r: 4, c: 4)).isEmpty)
    }

    @Test("vertical line of 5 clears")
    func verticalFive() {
        var board = Board()
        board.place([(0, 3), (1, 3), (2, 3), (3, 3), (4, 3)], 2)
        #expect(board.findLinesThrough(Cell(r: 2, c: 3)).count == 5)
    }

    @Test("diagonal (down-right) line of 5 clears")
    func diagonalFive() {
        var board = Board()
        board.place([(0, 0), (1, 1), (2, 2), (3, 3), (4, 4)], 3)
        #expect(board.findLinesThrough(Cell(r: 2, c: 2)).count == 5)
    }

    @Test("anti-diagonal line of 5 clears")
    func antiDiagonalFive() {
        var board = Board()
        board.place([(0, 4), (1, 3), (2, 2), (3, 1), (4, 0)], 4)
        #expect(board.findLinesThrough(Cell(r: 2, c: 2)).count == 5)
    }

    @Test("line longer than 5 includes every matching cell")
    func longLine() {
        var board = Board()
        board.place([(4, 0), (4, 1), (4, 2), (4, 3), (4, 4), (4, 5), (4, 6)], 5)
        #expect(board.findLinesThrough(Cell(r: 4, c: 3)).count == 7)
    }

    @Test("union of two directions counts the shared cell once")
    func crossCountsSharedCellOnce() {
        var board = Board()
        board.place([(4, 2), (4, 3), (4, 4), (4, 5), (4, 6)], 0)  // horizontal
        board.place([(2, 4), (3, 4), (5, 4), (6, 4)], 0)  // vertical through (4,4)
        // 5 horizontal + 4 additional vertical, with (4,4) not double counted.
        #expect(board.findLinesThrough(Cell(r: 4, c: 4)).count == 9)
    }

    @Test("the returned cells are all distinct")
    func noDuplicates() {
        var board = Board()
        board.place([(4, 2), (4, 3), (4, 4), (4, 5), (4, 6)], 0)
        board.place([(2, 4), (3, 4), (5, 4), (6, 4)], 0)
        let line = board.findLinesThrough(Cell(r: 4, c: 4))
        #expect(Set(line).count == line.count)
    }

    @Test("empty cell has no line")
    func emptyCellHasNoLine() {
        #expect(Board().findLinesThrough(Cell(r: 0, c: 0)).isEmpty)
    }

    @Test("a spawn landing next to an existing run completes the line")
    func spawnCompletesLine() {
        var board = Board()
        board.place([(4, 2), (4, 3), (4, 4), (4, 5)], 6)
        board.place([(4, 6)], 6)  // the just-spawned marble
        #expect(board.findLinesThrough(Cell(r: 4, c: 6)).count == 5)
    }
}

@Suite("findPath")
struct FindPathTests {

    @Test("finds a direct path across an empty board")
    func directPath() throws {
        let path = try #require(Board().findPath(from: Cell(r: 0, c: 0), to: Cell(r: 0, c: 4)))
        #expect(path.first == Cell(r: 0, c: 0))
        #expect(path.last == Cell(r: 0, c: 4))
    }

    @Test("every step is an orthogonal neighbor — no diagonal jumps")
    func stepsAreOrthogonal() throws {
        var board = Board()
        // Vertical wall with a gap at row 0 and row 8.
        board.place([(1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2)], 1)
        let path = try #require(board.findPath(from: Cell(r: 0, c: 0), to: Cell(r: 0, c: 8)))
        for (a, b) in zip(path, path.dropFirst()) {
            #expect(abs(a.r - b.r) + abs(a.c - b.c) == 1)
        }
    }

    @Test("path never passes through an occupied cell")
    func pathAvoidsOccupied() throws {
        var board = Board()
        board.place([(1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2)], 1)
        let from = Cell(r: 0, c: 0)
        let to = Cell(r: 0, c: 8)
        let path = try #require(board.findPath(from: from, to: to))
        for cell in path where cell != from && cell != to {
            #expect(board[cell] == nil)
        }
    }

    @Test("returns nil when the destination is walled off")
    func walledOff() {
        let board = Board.walledAtColumn(4)
        #expect(board.findPath(from: Cell(r: 0, c: 0), to: Cell(r: 0, c: 8)) == nil)
    }

    @Test("returns nil when the destination is occupied")
    func destinationOccupied() {
        var board = Board()
        board[0, 3] = 2
        #expect(board.findPath(from: Cell(r: 0, c: 0), to: Cell(r: 0, c: 3)) == nil)
    }

    @Test("a path to itself is a single step")
    func pathToSelf() throws {
        let path = try #require(Board().findPath(from: Cell(r: 3, c: 3), to: Cell(r: 3, c: 3)))
        #expect(path == [Cell(r: 3, c: 3)])
    }
}

@Suite("reachableFrom")
struct ReachableFromTests {

    @Test("does not include cells across a wall")
    func stopsAtWall() {
        let board = Board.walledAtColumn(4)
        let reachable = board.reachableFrom(Cell(r: 0, c: 0))
        #expect(!reachable.contains { $0.c > 4 })
    }

    @Test("an empty board reaches every cell except the origin")
    func reachesWholeBoard() {
        let reachable = Board().reachableFrom(Cell(r: 0, c: 0))
        #expect(reachable.count == Marmor.size * Marmor.size - 1)
        #expect(!reachable.contains(Cell(r: 0, c: 0)))
    }
}

@Suite("colorCounts")
struct ColorCountsTests {

    @Test("counts each color's occurrences on the board")
    func counts() {
        var board = Board()
        board.place([(0, 0), (0, 1), (0, 2)], 3)
        board.place([(1, 0)], 5)
        let counts = board.colorCounts()
        #expect(counts.count == Marmor.colors)
        #expect(counts[3] == 3)
        #expect(counts[5] == 1)
        #expect(counts[0] == 0)
    }

    @Test("ignores colors outside the level's range instead of overflowing")
    func ignoresOutOfRangeColors() {
        var board = Board()
        // A board that outlived a level change can hold colors the current
        // level doesn't use. Counting them would write past the array's end.
        board.place([(0, 0), (0, 1)], 7)
        board.place([(1, 0)], 2)
        let counts = board.colorCounts(colorCount: 5)
        #expect(counts.count == 5)
        #expect(counts[2] == 1)
        #expect(counts.reduce(0, +) == 1)
    }
}

@Suite("longestRunThrough")
struct LongestRunThroughTests {

    @Test("an isolated empty cell has run length 1 for any color")
    func isolated() {
        #expect(Board().longestRunThrough(Cell(r: 4, c: 4), color: 0) == 1)
    }

    @Test("counts contiguous same-color neighbors on both sides")
    func bridgesBothSides() {
        var board = Board()
        board.place([(4, 1), (4, 2), (4, 3)], 2)
        board.place([(4, 5), (4, 6)], 2)
        // (4,4) is empty; filling it with color 2 bridges into a run of 6.
        #expect(board.longestRunThrough(Cell(r: 4, c: 4), color: 2) == 6)
    }

    @Test("a mismatched color sees no boost from neighbors")
    func mismatchedColor() {
        var board = Board()
        board.place([(4, 3), (4, 5)], 2)
        #expect(board.longestRunThrough(Cell(r: 4, c: 4), color: 3) == 1)
    }

    @Test("detects diagonal runs too")
    func diagonal() {
        var board = Board()
        board.place([(0, 0), (1, 1), (2, 2)], 5)
        // (3,3) empty; filling with color 5 extends the diagonal to length 4.
        #expect(board.longestRunThrough(Cell(r: 3, c: 3), color: 5) == 4)
    }
}

@Suite("scoreForClear")
struct ScoreForClearTests {

    @Test("base case: exactly 5 marbles")
    func baseCase() {
        #expect(scoreForClear(5) == 10)
    }

    @Test("longer lines score a bonus")
    func longerLines() {
        #expect(scoreForClear(6) > scoreForClear(5))
        #expect(scoreForClear(9) == 9 * 2 + 4 * 3)
    }
}
