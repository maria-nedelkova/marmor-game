# Plan: Godot, the level map, the new scoring, and a backend

Written 2026-10-06, as a handoff to a machine that can actually build and ship
this. Nothing here is implemented yet — this file is the decisions and the
reasoning behind them, so the next session doesn't start by re-deriving them.

Source of truth for game logic is still the web repo (`../marmor`) at commit
`cf8305a`. Read that before writing new logic; it is ahead of this repo (see
*Where the port actually stands*).

---

## 1. The decision: Godot

Mobile is the focus from here. **The new scoring system and the level map are
not being built on web** — the web version stays as it is, as a playable
prototype and as the reference implementation of the game rules.

Why Godot over the alternatives:

The look matters a lot here, and the target design (see
`docs/reference/level-map.jpeg`) is a pixel-art space map with heavy neon
bloom, glowing nodes, and a starfield. That is a *renderer* problem, not a UI
toolkit problem.

- Every effect in that reference is **easier in a real renderer than in CSS**.
  The web version's neon is layered `box-shadow` imitating bloom. Godot does
  actual bloom as a post-process, which is why the reference looks the way it
  does and the web version only approximates it.
- Pixel art becomes a texture with nearest-neighbour filtering instead of a
  CSS grid of `<div>`s (a 16x18 sprite is currently 288 DOM nodes).
- Parallax starfields, shader-animated nebulae and particles are built in.

Rejected, and why:

- **SwiftUI / Jetpack Compose native** — would work, but means hand-rolling
  effects an engine gives away. No benefit for a turn-based puzzle.
- **React Native + Skia** — genuinely strong, and would have let the
  TypeScript engine port across unchanged. Lost to Godot on game-feel tooling
  and on bloom/particles being first-class rather than assembled.
- **Capacitor wrapper around the web app** — cheapest path to the stores and
  keeps the CSS, but it is the prototype shipped as the product, and it caps
  how good this can look.

### One repo, both stores

This is the other half of the win, and it is real: **one Godot project ships
to iOS and Android.** One codebase, one set of scenes and assets, an export
preset per platform. Native would have meant Swift *and* Kotlin — two
codebases and every feature built twice.

Three things that stay per-platform anyway:

- **iOS still needs a Mac.** Godot exports an Xcode project; signing and
  submitting require Xcode on a current macOS. Android builds from anything.
  One repo, but not one machine.
- Store metadata, icons, splash screens, signing and permissions. Config,
  not code.
- Third-party SDKs — ads, analytics, IAP — are where per-platform plugin
  work creeps back in.

The cost of this decision is the engine rewrite. That is the next section.

---

## 2. What happens to the Swift port

`Sources/MarmorEngine` and `Sources/MarmorAudio` are a careful, well-tested
port of the web engine. Godot does not run Swift natively, so there is a real
decision here, and it should be settled **on day one by exporting a
hello-world to both an iOS and an Android device**, not after a game is built
on top of it.

Three options, honestly:

| Option | Keeps the Swift port | iOS | Android |
| --- | --- | --- | --- |
| **GDScript** | No — third rewrite of the engine | Best supported | Best supported |
| **C# (.NET)** | No — but a Swift→C# port is mechanical | Supported; verify early | Supported; verify early |
| **SwiftGodot** (GDExtension) | Yes — `MarmorEngine` nearly as-is | Workable, less-trodden | **Weak — see below** |

**Recommendation: GDScript.** C# if you specifically want static typing and a
mechanical translation from the Swift, but prove its mobile export on day one,
because that has historically been the rockier path.

Three things that get wrongly attributed to this choice, and one that doesn't:

- **One repo for both stores is Godot, not GDScript.** Every option above
  gives you that. GDScript just reaches it with the least export friction —
  no .NET runtime to bundle, smaller binaries, fewer moving parts.
- **The looks are the renderer, not the language.** Bloom, shaders,
  particles and parallax are `WorldEnvironment` and shader code; they read
  identically from C#. Choosing GDScript costs nothing visually.
- **Performance is a non-issue.** GDScript is slower than C#, which would
  matter for a heavy simulation. This game runs BFS on an 81-cell board,
  turn-based. It could be written in almost anything.
- **Testing is the real trade.** `swift test` and XCTest are excellent;
  GDScript means a community addon — GUT or GdUnit4. Both work, both are
  less polished. See *Test framework* below; pick on day one, because the
  plan depends on porting the test suite *first*.

One thing to do deliberately: **use GDScript's static typing everywhere**
(`var n: int`, typed parameters and returns). It is optional in Godot 4 and
off by default, and the Swift port leans on strong types — particularly in
the spawn and scoring paths. Writing untyped GDScript would quietly discard
the safety that port was relying on.

### Why not SwiftGodot, despite it being the only option that keeps the engine

Android is the reason. SwiftGodot reaches Android through Swift's Android
toolchain, which is immature, and stacking that on GDExtension-on-Android is
two experimental things propping each other up. For an iOS-only game it would
be a reasonable bet. For iOS **and** Android it undermines the single biggest
reason to pick Godot at all — one codebase, both platforms.

(An earlier draft of this file recommended trying SwiftGodot first, on the
grounds that it preserves `MarmorEngine`. That was written before cross-
platform was settled as a requirement. It is the wrong call once Android is in
scope.)

### Port from the TypeScript, not from the Swift

The web repo is the source to translate from. Two reasons, both load-bearing:

- **It is complete.** The Swift port has no tool system — no `tools.ts`, no
  `bombAt`, no `shuffleBoardColors`. Porting from Swift means porting from
  TypeScript anyway for that half, in a second pass, after the idioms have
  already been bent once.
- **It is verified.** 134 tests, 1 575 assertions, and it has been played.
  The Swift port **has never been through a compiler** (its own README says
  so). Using unverified code as the specification lets its mistakes
  propagate silently into GDScript, with no way to tell a porting bug from
  an inherited one.

**The Swift port still earns its keep — as notes, not as source.** Its
README's "Notable differences" section is exactly the list of traps in
translating *out of JavaScript idioms*, and GDScript hits the same ones:

- JS `sort` is stable; GDScript's `sort_custom` is not. `findTopThreats`
  needs an explicit total order or which line the spawner blocks varies run
  to run.
- `Math.random()` is a global the web tests monkey-patch. GDScript has no
  such global, so randomness wants injecting — the same answer Swift reached.
- Maps keyed by `"r,c"` strings want a real hashable cell type.
- `findIndex`/`splice` on `-1` silently grabs the *last* free cell. The
  Swift port refused to inherit that; so should this one.

So: **TypeScript for what the code does, the Swift README for how not to
mistranslate it.** That is a real head start, and it is the part of this
repo that survives.

### This repo, renamed — not a new one

Renamed from `marmor-ios` to **`marmor-game`** rather than starting fresh.
GitHub redirects the old remote URL, so nothing breaks, and this file keeps
its history — which is now the record of these decisions. A new repo would
have stranded both.

**Do not delete the Swift package yet.** It gets read constantly during the
port, per the section above. Prune it once the GDScript engine is green and
its tests pass — not before.

### Why rewriting the engine is a smaller loss than it sounds

The engine is about 400 lines of pure logic — BFS pathfinding, flood fill,
line detection, scoring, weighted spawn choice. It is not a system to dread
rebuilding.

And the behaviour is already pinned down twice over: by the web suite that
actually runs (134 tests, 1 575 assertions), and by the Swift port's written
reasoning about where a translation goes wrong. Between them the subtle parts
— the blocking AI's tie-breaks, the colour-affinity dial, the ladder's
one-dial-per-round rule — are documented rather than folklore. Translate the
tests first, then make them pass.

Do not pick on this table alone. All three export stories move, and this was
written without being able to test any of them.

### Test framework: GdUnit4

A close call, and a **reversible one** — the tests are plain assertions over
pure functions, so switching later is largely find-and-replace on assertion
syntax. Not worth agonising over.

**GdUnit4**, because:

- It is built for Godot 4; GUT carries history from the Godot 2/3 era.
- It supports GDScript **and** C#, which hedges the language decision in
  section 2 — if the GDScript rewrite goes badly, the tests survive the
  move to C#.
- Editor-integrated test inspector plus a VS Code extension. Worth something
  while learning the engine and porting at the same time.
- Fluent assertions (`assert_that(x).is_equal(y)`) read closer to what the
  XCTest suite already expresses than GUT's plainer `assert_eq`.

**GUT's case is genuine**: simpler, lighter, longer track record, and far
more tutorials and community answers written against it. If the tests stay
mostly straight equality checks, it is entirely adequate.

One argument deliberately *not* made for GdUnit4: its data-generator and
fuzzing support. `FuzzTests.swift` does not need it — the Swift port rolls a
seeded SplitMix64 so the 10k-move fuzz runs are reproducible, and that is
framework-agnostic. The PRNG gets ported to GDScript either way.

> Both are community addons and both move. Check each one's recent activity
> and its compatibility with the exact Godot version you install before
> committing. That is a two-minute look at their repos, and it beats this
> file — written at a remove, and without being able to run either.


---

## 3. The scoring system (new — not in any implementation yet)

### The King's target escalates per level

Today `KING_SCORE` is a flat 100 and the ladder gets harder by making 100
harder to earn. That changes: each level gets its own target.

| # | World | King's target |
| --- | --- | --- |
| 01 | NEONIA-1 | 100 |
| 02 | SULFUR-KOR | 300 |
| 03 | CRYSTALLOS | 600 |
| 04 | BLACK HOLE 04 | 1 000 |
| 05 | CELESTIAL RING STATION | 1 600 |
| 06 | TERRA-FORMER | 2 400 |
| 07 | GAIA PRIME | 3 500 |
| 08 | GALACTIC CORE | 5 000 |

Line values scale with the same per-level multiplier (`target / 100`), so
clearing a line in level 4 is worth 10x what it is in level 1. Current
formula, from `engine.ts` / `Engine.swift`:

```
scoreForClear(n) = n*2 + max(0, n-5)*3     // a line of 5 = 10 points
```

becomes that, multiplied by the level's multiplier.

### Read this before tuning the curve

**If the target and the line value scale together, the level plays exactly the
same.** Level 4 at a 1000 target with 10x line values is the same ten lines as
level 1 at 100. The numbers get bigger; the difficulty does not move.

That is deliberate, not an oversight. Difficulty continues to come from the
dials already in `levels.ts` (colours, spawn count, preview count, block
probability, colour affinity, spawn-on-clear). The escalating score is a
**reward** change, and where it actually bites is the leaderboard: beating
level 8 contributes 5 000 to your monthly total where level 1 contributes 100,
so depth is worth fifty times the time. That is the pull forward.

The curve above is a proposal, not a decision. It was chosen so level 8 is 50x
level 1 — enough that depth beats grinding, not so much that levels 1–7 stop
counting. Straight doubling would make level 8 worth 128x and reduce the board
to "did you beat the last level".

### Tools do not scale with the target

**Decided 2026-10-06: a hammer means the same thing in GALACTIC CORE as in
NEONIA-1.** The score escalates; the toolkit does not.

This keeps the two systems independent, which is worth more than the
symmetry would have been. Tool charges stay a progression reward — one more
thing you can do each world — rather than a second currency that has to be
rebalanced every time a target moves. `game/core/tools.gd` reads neither
`target` nor `multiplier`, and says so in place.

### Monthly leaderboard

Scores accumulate across level completions and **nullify at the end of each
month**, so every month has a fresh set of leaders.

**Open question — how a replay counts.** Every unlocked level is replayable
forever, which creates a loophole: if each completion adds to the monthly
total, grinding level 1 is the fastest way to climb, and the board rewards
repetition over depth.

Recommended fix: the monthly total is the **sum of your best score on each
level**. Replaying still matters — beating your own record raises the total —
but repetition alone earns nothing. An alternative is sum-of-bests plus a
one-off first-clear bonus per level, which pushes harder toward progressing.
Not yet decided.

---

## 4. The level map

The map is **the first screen the player sees**, replacing the straight-to-
board launch.

- Eight worlds, one per level, in the order above.
- **Unlocked gradually**: beating level N unlocks N+1.
- **Every unlocked level is replayable**, any number of times.
- **Each level is a different king** — its own avatar, matched to its world.
- **Tapping the game name returns to the map** from anywhere in a level.

The design target is `docs/reference/level-map.jpeg`, and the brief is "this
precise design and even better."

### Fix these in the reference

The reference image is sloppy in specific ways. It is correct about mood and
layout, wrong about structure:

- **Duplicate `07`** — three nodes carry it. There are eight levels, numbered
  01–08 exactly once each.
- **A `10` that does not exist** — twice. The ladder ends at 08.
- **Connection lines are wrong** — they wander and cross. The path should
  trace 01 → 08 in order, so the route reads as the progression it is.
- **Unnamed nodes** — the gold torus under 01, the comet, the nebula. Either
  name them as real levels or drop them to background scenery; they currently
  read as levels you cannot reach.
- `GALACTIC CORE` is the level 08 boss node and should look like a finale.

### King avatars

Eight distinct heads, one per world, in the existing hand-authored pixel style
(`src/game/sprites/` in the web repo shows the approach: `row()` helpers plus
a small named palette). Sketch from the reference:

```
01  NEONIA-1                plain crown, green
02  SULFUR-KOR              flame crown, orange
03  CRYSTALLOS              shard crown, violet
04  BLACK HOLE 04           faceless, event horizon
05  CELESTIAL RING STATION  visored helm, gold
06  TERRA-FORMER            leaf crown, green
07  GAIA PRIME              orbital halo, cyan
08  GALACTIC CORE           dark silhouette
```

Still open whether these get drawn up front or whether the map ships with a
placeholder king on every node and the avatars land as a focused second pass.

### Keep the data portable

Levels, names, kings, unlock rules and the score curve should be **plain data
in one file**, the way `levels.ts` already is. That file is the thing that
survives; the presentation layer around it is disposable and should be
treated that way. This is the single lesson worth carrying over from the web
version — its engine ported cleanly and its 2 000 lines of CSS port not at
all.

---

## 5. Backend

Needed for profiles and for the monthly leaderboard to mean anything across
devices. Not started. Deliberately after the map and the scoring, since both
can run against local storage first.

What it has to do:

- **User profiles** — identity that survives a reinstall and a new device.
  The web version has only an anonymous local `playerId`.
- **Score submission** — per level, per player, keeping the best.
- **Monthly leaderboard** — ranked totals, reset at the month boundary.
  Decide whether past months are archived (a "previous month's champion" is
  cheap to keep and gives the reset some weight) or discarded.
- **Anti-cheat, at least token** — scores arriving from a client that can be
  modified. Server-side sanity bounds at minimum: a score above what the
  level's target and multiplier permit is not possible honestly.

Nothing is chosen for the stack yet. The requirements are small enough that
almost anything serves.

---

## 6. Where the port actually stands

Better than expected. The Swift engine was last caught up on 2026-09-14, and
**the only game-logic change on web since then is the tool system**:

```
d9a7d08  Add the tools model and their board operations
2cefce0  Wire up the tools: charges, board actions and the rack
6f57560  Give the tools pixel-art icons and a phone-width rack
9bc9e76  Put the tools above the board and the top bar below it
a1280a9  Move the mobile controls up between the mascots, tools below the board
bd59b49  Size the mobile queue preview for four marbles, not three
7dad245  Add the pouch and the bomb, and make foresight predict places
52334ae  Announce the new tool on the round-cleared screen
1913581  Persist the crystal ball's forecast across a tab eviction
```

Everything after 2026-10-01 is CSS, a theme system, and then the removal of
that theme system. None of it touches game rules.

So the logic gap is:

- **`src/game/tools.ts` (132 lines)** — six tools on an unlock ladder, with a
  charge economy. Hammer, flask (swap two), dice (reroll the queue), pouch
  (shuffle the board's colours), bomb (clear a 3x3), crystal ball (commit and
  reveal the next spawn's *places*).
- **Two engine operations** — `bombAt(board, cell)` and
  `shuffleBoardColors(board)`. Both exist in `engine.ts`, neither in
  `Engine.swift`.
- **`progress.ts`** — deliberately not ported; see the README's reasoning,
  which still holds. Its `foreseen` field (the crystal ball's committed
  forecast) is newer than that note.

Also still true from the README: **none of this Swift has ever been
compiled.** It was written on a machine with no working toolchain. Expect to
fix things on the first `swift test`, and do that before judging whether
SwiftGodot is viable — a failing build there is not evidence about Godot.

---

## 7. Suggested order

1. Hello-world Godot export to **both** a real iOS device and a real Android
   device, in whichever language you mean to use. Settle section 2 before
   anything is built on top of it. Doing both now is the point — the whole
   case for Godot is that one codebase ships to two stores, and that claim
   should be tested while it is cheap to act on.
2. Install GdUnit4 (see section 2) and port the engine tests first, then make
   them pass. Translate from the **web** suite (`src/game/*.test.ts` — 134
   tests, and the only one that has ever run), reading the Swift port's
   README and `Tests/MarmorEngineTests/` alongside for the translation traps.
   Writing the assertions before the implementation is what keeps the subtle
   behaviour (blocking tie-breaks, colour affinity, the ladder guardrails)
   from quietly changing in the rewrite.
3. Level/world data as one plain-data file: names, kings, targets,
   multipliers, unlock rules.
4. The level map screen, against local storage.
5. The board, driven by the ported engine.
6. The tool system (port `tools.ts` while doing it).
7. Backend, profiles, the real monthly leaderboard.

---

## Open questions

- GDScript or C#? (SwiftGodot is ruled out by Android — see section 2.)
- Replays: sum-of-bests, or sum-of-bests plus a first-clear bonus?
- Exact score curve — the table in section 3 is a proposal.
- King avatars up front, or a placeholder pass first?
- Are past months archived, or discarded at reset?
- Do the tools carry over to mobile unchanged? They were designed around a
  phone-width rack, so probably — but the rack is a layout question now that
  the charge economy is settled.
