# marmor-ios

Native iOS port of [Marmor](../marmor) — a King-vs-Pretender marble-lines
puzzle in the spirit of the old DOS *Color Lines*.

## Status

`MarmorEngine`, the game logic, is ported from the web version's
`src/game/engine.ts`. The SwiftUI app target does not exist yet.

> **Not yet compiled.** This was written on a Mac with no working Swift
> toolchain, so it has never been through a compiler. Expect to fix a few
> things on the first `swift test`.

## Package

```
Sources/MarmorEngine/
  Constants.swift   board size, palette size, line minimum, scoring knobs
  Cell.swift        a board coordinate
  Board.swift       9x9 field, flat-backed, value semantics
  Engine.swift      BFS pathfinding, flood fill, line detection, scoring
  Spawning.swift    weighted color choice, threat detection, spawn placement

Tests/MarmorEngineTests/
  TestSupport.swift  seeded PRNG + board-building helpers
  EngineTests.swift  pure logic
  SpawningTests.swift  the blocking "AI"
  FuzzTests.swift    10k random legal moves, and path/reachability agreement
```

```
swift test
```

## Notable differences from the TypeScript original

Everything is a faithful port except where Swift makes a better option
available, or forbids the original approach outright:

- **Randomness is injected, not global.** The TypeScript version calls
  `Math.random()` inline and its tests monkey-patch the global to pin it.
  Swift can't do that, so every random-dependent function takes an
  `inout RandomNumberGenerator`, with a convenience overload supplying the
  system generator. Tests use a seeded SplitMix64, which also makes the fuzz
  suite reproducible — the original's fuzz failures are not.
- **`Board` is a struct with flat storage**, not an array of arrays. Value
  semantics make `cloneBoard` unnecessary; assignment already copies.
- **`Cell` is `Hashable`**, so `findLinesThrough` dedupes with a `Set` rather
  than keying a `Map` by `"r,c"` strings.
- **`findTopThreats` sorts on a total order** (length desc, then row, column,
  color). JavaScript's sort is stable and the original leans on that; Swift's
  is not, so without an explicit tie-break, which line the spawner blocks
  could vary run to run.
- **`assignSpawnCells` falls back to a random cell** if a blocker's cell has
  somehow already been taken. This shouldn't be reachable, but the original's
  `findIndex`/`splice` pair would silently grab the *last* free cell on a
  `-1`, which is a bad failure mode to inherit.
- **CSS layout constants are dropped** (`CELL_SIZE_PX` and friends) — SwiftUI
  does its own layout, so there's nothing for the view to match.
