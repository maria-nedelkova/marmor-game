/// Index into the color palette. `nil` marks an empty square.
public typealias ColorIndex = Int

/// The 9x9 playing field.
///
/// Backed by a single flat array rather than the array-of-arrays the
/// TypeScript version uses — one allocation instead of ten, and row-major
/// iteration stays cache-friendly. Being a struct, it has value semantics, so
/// `let snapshot = board` already makes an independent copy and the original's
/// `cloneBoard` has no Swift equivalent.
public struct Board: Equatable, Sendable {
    private var storage: [ColorIndex?]

    public init() {
        storage = Array(repeating: nil, count: Marmor.size * Marmor.size)
    }

    public subscript(r: Int, c: Int) -> ColorIndex? {
        get { storage[r * Marmor.size + c] }
        set { storage[r * Marmor.size + c] = newValue }
    }

    public subscript(cell: Cell) -> ColorIndex? {
        get { self[cell.r, cell.c] }
        set { self[cell.r, cell.c] = newValue }
    }

    public static func inBounds(_ r: Int, _ c: Int) -> Bool {
        r >= 0 && r < Marmor.size && c >= 0 && c < Marmor.size
    }

    /// Every empty square, in row-major order.
    public func emptyCells() -> [Cell] {
        var out: [Cell] = []
        out.reserveCapacity(storage.count)
        for r in 0..<Marmor.size {
            for c in 0..<Marmor.size where self[r, c] == nil {
                out.append(Cell(r: r, c: c))
            }
        }
        return out
    }

    /// How many marbles are on the board.
    public var marbleCount: Int {
        var total = 0
        for cell in storage where cell != nil { total += 1 }
        return total
    }

    /// Count of each color currently on the board, indexed by color.
    ///
    /// `colorCount` is how many colors are in play this level (see
    /// `LevelConfig.colors`); it defaults to the full palette so the engine is
    /// still usable — and testable — without a level in hand.
    public func colorCounts(colorCount: Int = Marmor.colors) -> [Int] {
        var counts = Array(repeating: 0, count: colorCount)
        for cell in storage {
            // A color outside the current level's range can only appear if a
            // board outlived a level change; ignoring it beats writing past
            // the end of the counts array.
            if let cell, cell < colorCount { counts[cell] += 1 }
        }
        return counts
    }
}
