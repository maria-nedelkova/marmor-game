/// A board coordinate. `Hashable` so sets of cells can be built directly —
/// the TypeScript original had to key a `Map` by `"\(r),\(c)"` strings to get
/// the same deduplication.
public struct Cell: Hashable, Sendable {
    public var r: Int
    public var c: Int

    public init(r: Int, c: Int) {
        self.r = r
        self.c = c
    }
}

extension Cell: CustomStringConvertible {
    public var description: String { "(\(r),\(c))" }
}
