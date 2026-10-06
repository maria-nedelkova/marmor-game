# marmor-ios

Native iOS port of [Marmor](../marmor) — a King-vs-Pretender marble-lines
puzzle in the spirit of the old DOS *Color Lines*.

## Status

> **The direction has changed: this is becoming a Godot game, not a SwiftUI
> one.** Read [PLAN.md](PLAN.md) first — it carries the decision and its
> reasoning, the new escalating score system, the level map, and what all of
> that means for the Swift code below. Whether this package survives at all
> depends on a language choice that PLAN.md lays out but does not make.

`MarmorEngine` (game logic) and `MarmorAudio` (sound) are ported from the web
version's `src/game/engine.ts` and `src/audio/sound.ts`. The SwiftUI app target
does not exist and now never will in that form.

The engine is one feature behind the web version — the six-tool system and its
two board operations (`bombAt`, `shuffleBoardColors`). Everything else that
landed on web since is presentation. PLAN.md section 6 has the detail.

Because of that gap, and because this Swift has never compiled, **the port
source is the web repo's TypeScript, not this package.** What this package
contributes is its reasoning: the "Notable differences" section below is the
list of traps in translating out of JavaScript idioms, and they apply just as
well to GDScript. Keep it until the Godot engine's tests are green.

> **Not yet compiled.** This was written on a Mac with no working Swift
> toolchain, so it has never been through a compiler. Expect to fix a few
> things on the first `swift test`.

## Package

```
Sources/MarmorEngine/
  Constants.swift   board size, palette ceiling, line minimum, King's target
  Cell.swift        a board coordinate
  Board.swift       9x9 field, flat-backed, value semantics
  Engine.swift      BFS pathfinding, flood fill, line detection, scoring
  Spawning.swift    weighted color choice, threat detection, spawn placement
  Levels.swift      the eight-round difficulty ladder, as data
  Score.swift       Hall of Pretenders ranking (progress, sort key, ordering)

Sources/MarmorAudio/
  Waveform.swift    oscillator shapes, polyBLEP anti-aliasing
  Biquad.swift      RBJ lowpass/highpass, matching Web Audio's filter design
  Synth.swift       envelopes, blip and noise-burst rendering, mixing
  Sfx.swift         the eight game sounds, each rendered to a buffer
  SoundPlayer.swift AVAudioEngine playback, buffer cache, mute

Tests/MarmorEngineTests/
  TestSupport.swift  seeded PRNG + board-building helpers
  EngineTests.swift  pure logic
  SpawningTests.swift  the blocking "AI", color weighting, the affinity dial
  LevelsTests.swift  ladder guardrails, incl. the one-dial-per-round rule
  ScoreTests.swift   ranking, progress, sort-key packing
  FuzzTests.swift    10k random legal moves, and path/reachability agreement

Tests/MarmorAudioTests/
  SynthTests.swift  envelopes, waveforms, filter response, pitch sweeps
  SfxTests.swift    per-effect duration, level, and well-formedness
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
- **`score.ts`'s free functions became properties** — `progressOf(entry)` reads
  better as `entry.progress`, `isBetterRun(a, b)` as `a.isBetter(than: b)`.
  Ranking also gets a final tie-break on `id`, since the web version leans on
  JavaScript's stable sort for entries identical down to the timestamp and
  Swift's sort is not stable.
- **`assignSpawnCells` keeps labelled default parameters** rather than the
  `SpawnOptions` object the web version adopted. That object exists to avoid a
  run of positional arguments, which Swift's argument labels already solve.

### Two web modules with no Swift counterpart

- **`rng.ts` is not ported.** It exists because browser privacy extensions
  shim `Math.random` to return degenerate values, which silently wrecks a
  spawn picker. Swift has no global to shim, and this port already threads a
  `RandomNumberGenerator` through every random-dependent function, so the
  problem it solves cannot occur here.
- **`progress.ts` is not ported yet.** Its whole design rests on
  `sessionStorage` semantics — survives a reload, dies with the tab — to tell
  "iOS evicted my backgrounded tab" apart from "I left." iOS has no equivalent
  boundary; the same distinction needs scene-phase notifications and a real
  freshness check against a file or `UserDefaults`. Porting it line by line
  would carry over reasoning that doesn't hold. It belongs with the app layer.

## Audio

Same principle as the web version: no audio files, everything synthesized at
runtime. The approach differs though, because Web Audio and AVAudioEngine are
built for different things.

Web Audio is a live node graph — the web version creates oscillators, gains and
filters per sound, wires them to the destination, and schedules parameter
automation. AVAudioEngine can do that, but attaching and detaching nodes
mid-playback is expensive and prone to glitching. So instead each effect is
**rendered offline into a PCM buffer once, cached, and replayed** through a
pool of twelve `AVAudioPlayerNode`s so overlapping sounds don't cut each other
off. Multi-part effects that the web version staggers with `setTimeout` — the
clear chime's voices, the win fanfare's notes, the king's landing thud — are
mixed into a single buffer at the right sample offsets.

The payoff is that all the actual sound design is pure functions from
parameters to `[Float]`, with no reference to AVFoundation, so it's unit-
testable without an audio device. Two other deliberate choices:

- **PolyBLEP band-limiting** on the square and sawtooth oscillators. Web
  Audio's built-in oscillators are band-limited; a naive `phase < 0.5 ? 1 : -1`
  is not, and it aliases audibly on the brighter blips.
- **`AVAudioSession` is `.ambient` with `.mixWithOthers`**, so the game
  respects the silent switch and doesn't stop whatever the player is already
  listening to. The web version has no equivalent concern.
