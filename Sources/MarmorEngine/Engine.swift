/// Pure game logic — no UI, no randomness. Every function here is a
/// straightforward transform over `Board`, so it can be unit-tested and
/// rendered by anything. Port of `src/game/engine.ts` from the web version.

/// Orthogonal steps, for travel.
private let travelDirections = [(1, 0), (-1, 0), (0, 1), (0, -1)]

/// The four line axes: horizontal, vertical, and both diagonals. Only one
/// direction per axis is listed; the scans below walk each axis both ways.
private let lineDirections = [(0, 1), (1, 0), (1, 1), (1, -1)]

extension Board {

    // MARK: - Movement

    /// BFS shortest path between two cells through empty cells only
    /// (4-directional). Returns the full walkable path inclusive of both ends,
    /// or `nil` if unreachable.
    ///
    /// `from` is not required to be empty — it holds the marble being moved.
    /// `to` must be empty, since only empty cells are ever enqueued.
    public func findPath(from: Cell, to: Cell) -> [Cell]? {
        let n = Marmor.size
        var visited = Array(repeating: false, count: n * n)
        var prev = [Cell?](repeating: nil, count: n * n)
        var queue: [Cell] = [from]
        visited[from.r * n + from.c] = true

        var head = 0
        while head < queue.count {
            let cur = queue[head]
            head += 1
            if cur == to { break }
            for (dr, dc) in travelDirections {
                let nr = cur.r + dr
                let nc = cur.c + dc
                guard Board.inBounds(nr, nc) else { continue }
                guard !visited[nr * n + nc] else { continue }
                guard self[nr, nc] == nil else { continue }
                visited[nr * n + nc] = true
                prev[nr * n + nc] = cur
                queue.append(Cell(r: nr, c: nc))
            }
        }

        guard visited[to.r * n + to.c] else { return nil }

        var path: [Cell] = []
        var cur: Cell? = to
        while let step = cur {
            path.append(step)
            cur = prev[step.r * n + step.c]
        }
        return path.reversed()
    }

    /// Every empty cell reachable from `from` by 4-directional travel through
    /// empty cells (flood fill) — used to preview legal destinations.
    /// Does not include `from` itself.
    public func reachableFrom(_ from: Cell) -> [Cell] {
        let n = Marmor.size
        var visited = Array(repeating: false, count: n * n)
        var queue: [Cell] = [from]
        visited[from.r * n + from.c] = true
        var out: [Cell] = []

        var head = 0
        while head < queue.count {
            let cur = queue[head]
            head += 1
            for (dr, dc) in travelDirections {
                let nr = cur.r + dr
                let nc = cur.c + dc
                guard Board.inBounds(nr, nc) else { continue }
                guard !visited[nr * n + nc] else { continue }
                guard self[nr, nc] == nil else { continue }
                visited[nr * n + nc] = true
                let cell = Cell(r: nr, c: nc)
                out.append(cell)
                queue.append(cell)
            }
        }
        return out
    }

    // MARK: - Line detection

    /// The set of cells forming a line of at least `Marmor.lineMin` through
    /// `cell`, across all four axes, unioned. Empty if none.
    ///
    /// A single marble can close two lines at once (a cross, say); the shared
    /// cell is counted only once.
    public func findLinesThrough(_ cell: Cell) -> [Cell] {
        guard let color = self[cell] else { return [] }

        var seen = Set<Cell>()
        var result: [Cell] = []

        for (dr, dc) in lineDirections {
            var forward: [Cell] = []
            var nr = cell.r + dr
            var nc = cell.c + dc
            while Board.inBounds(nr, nc), self[nr, nc] == color {
                forward.append(Cell(r: nr, c: nc))
                nr += dr
                nc += dc
            }

            var backward: [Cell] = []
            nr = cell.r - dr
            nc = cell.c - dc
            while Board.inBounds(nr, nc), self[nr, nc] == color {
                backward.append(Cell(r: nr, c: nc))
                nr -= dr
                nc -= dc
            }

            guard backward.count + 1 + forward.count >= Marmor.lineMin else { continue }

            for member in backward.reversed() + [cell] + forward {
                if seen.insert(member).inserted { result.append(member) }
            }
        }

        return result
    }

    /// The length of the longest same-color run that would pass through an
    /// empty cell if it were filled with `color` — "how long a line would this
    /// complete." Used to spot near-complete lines worth defending against.
    public func longestRunThrough(_ cell: Cell, color: ColorIndex) -> Int {
        var best = 1
        for (dr, dc) in lineDirections {
            var length = 1

            var nr = cell.r + dr
            var nc = cell.c + dc
            while Board.inBounds(nr, nc), self[nr, nc] == color {
                length += 1
                nr += dr
                nc += dc
            }

            nr = cell.r - dr
            nc = cell.c - dc
            while Board.inBounds(nr, nc), self[nr, nc] == color {
                length += 1
                nr -= dr
                nc -= dc
            }

            if length > best { best = length }
        }
        return best
    }
}

// MARK: - Scoring

/// Base 2 points per marble, escalating bonus for longer lines.
public func scoreForClear(_ n: Int) -> Int {
    n * 2 + max(0, n - Marmor.lineMin) * 3
}
