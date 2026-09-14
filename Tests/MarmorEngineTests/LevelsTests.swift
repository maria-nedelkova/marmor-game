import Testing

@testable import MarmorEngine

/// The ladder is data, so the things that can break it are data mistakes: a
/// level that asks for a color the renderer can't paint, a preview that
/// promises more marbles than actually spawn, a round that quietly stacks two
/// difficulty increases. These tests are the guardrail for editing `levels` by
/// hand.
@Suite("the level ladder")
struct LevelLadderTests {

    @Test("every level fits the palette")
    func fitsPalette() {
        for level in levels {
            // The floor is the classic seven — the ladder only ever adds colors.
            #expect(level.colors >= 7)
            #expect(level.colors <= Marmor.colors)
        }
    }

    @Test("preview never promises more marbles than the spawn delivers")
    func previewFitsSpawn() {
        for level in levels {
            #expect(level.previewCount > 0)
            #expect(level.previewCount <= level.spawnCount)
        }
    }

    @Test("the board always starts with room to play")
    func startsWithRoom() {
        for level in levels {
            #expect(level.startCount > 0)
            #expect(level.startCount < Marmor.size * Marmor.size)
        }
    }

    @Test("blocking settings stay in a sane range")
    func blockingIsSane() {
        for level in levels {
            #expect(level.blockProbability >= 0)
            #expect(level.blockProbability <= 1)
            // Below 3, blocking hits lines so short it reads as random noise
            // rather than as the board pushing back.
            #expect(level.blockMinRunLength >= 3)
            #expect(level.colorAffinity >= 0)
            #expect(level.colorAffinity <= 1)
        }
    }

    // MARK: - The one-dial rule

    /// "Dimension" is not the same as "field": `spawnCount` and `previewCount`
    /// together express how much of the spawn you can plan around, so they're
    /// compared as one ratio. A round that raises both (3-of-3 → 4-of-4) has
    /// added marbles without hiding any, which is one increase, not two.
    struct Dimension: Sendable {
        let name: String
        let read: @Sendable (LevelConfig) -> Double
        /// Dimensions where a *lower* number is the harder setting.
        let lowerIsHarder: Bool
    }

    static let dimensions: [Dimension] = [
        Dimension(name: "colors", read: { Double($0.colors) }, lowerIsHarder: false),
        Dimension(name: "spawnCount", read: { Double($0.spawnCount) }, lowerIsHarder: false),
        Dimension(
            name: "previewShare",
            read: { Double($0.previewCount) / Double($0.spawnCount) },
            lowerIsHarder: true),
        Dimension(name: "startCount", read: { Double($0.startCount) }, lowerIsHarder: false),
        Dimension(name: "blockProbability", read: { $0.blockProbability }, lowerIsHarder: false),
        Dimension(
            name: "blockMinRunLength",
            read: { Double($0.blockMinRunLength) },
            lowerIsHarder: false),
        Dimension(name: "colorAffinity", read: { $0.colorAffinity }, lowerIsHarder: true),
        Dimension(name: "spawnOnClear", read: { $0.spawnOnClear ? 1 : 0 }, lowerIsHarder: false),
    ]

    /// Splits a round-to-round diff into dials that got harder and dials that
    /// got easier, accounting for the dimensions where lower is harsher.
    func diffRound(_ i: Int) -> (name: String, harder: [String], easier: [String]) {
        let previous = levels[i - 1]
        let current = levels[i]
        var harder: [String] = []
        var easier: [String] = []

        for dimension in Self.dimensions {
            let before = dimension.read(previous)
            let after = dimension.read(current)
            if before == after { continue }
            let gotHarder = dimension.lowerIsHarder ? after < before : after > before
            if gotHarder { harder.append(dimension.name) } else { easier.append(dimension.name) }
        }
        return (current.name, harder, easier)
    }

    @Test("each round raises exactly one dial")
    func oneDialPerRound() {
        for i in 1..<levelCount {
            let diff = diffRound(i)
            #expect(
                diff.harder.count == 1,
                "round \(i + 1) (\(diff.name)) raised \(diff.harder)")
        }
    }

    @Test("a round eases at most one dial, and only alongside a harder one")
    func easingIsCompensation() {
        for i in 1..<levelCount {
            let diff = diffRound(i)
            #expect(diff.easier.count <= 1, "round \(i + 1) (\(diff.name)) eased \(diff.easier)")
            // An easing is compensation for a heavier dial, never a free gift.
            if !diff.easier.isEmpty { #expect(diff.harder.count == 1) }
        }
    }

    @Test("no round currently eases anything")
    func nothingIsEased() {
        // The rule permits one compensating easing per round, but the ladder
        // as tuned uses none. Pinned so that adding an easing is a deliberate
        // act with a failing test to update, rather than something discovered
        // from a diff months later.
        for i in 1..<levelCount {
            let diff = diffRound(i)
            #expect(diff.easier.isEmpty, "round \(i + 1) (\(diff.name)) eased \(diff.easier)")
        }
    }

    // MARK: - Monotonicity

    @Test("colors, spawn count and start count never go backwards")
    func neverEasesBackwards() {
        for i in 1..<levelCount {
            #expect(levels[i].colors >= levels[i - 1].colors)
            #expect(levels[i].spawnCount >= levels[i - 1].spawnCount)
            #expect(levels[i].startCount >= levels[i - 1].startCount)
        }
    }

    @Test("every round is named and explains its twist")
    func namedAndExplained() {
        #expect(Set(levels.map(\.name)).count == levelCount)
        for level in levels { #expect(level.twist.count > 10) }
    }

    @Test("round 1 is the classic game, untouched")
    func roundOneIsClassic() {
        // Pinned exactly rather than by inequality: if a future tuning pass
        // drifts these, the ladder has silently stopped being an extension of
        // the original game and started being a different one.
        let first = levels[0]
        #expect(first.colors == 7)
        #expect(first.spawnCount == 3)
        #expect(first.previewCount == 3)
        #expect(first.startCount == 5)
        #expect(first.blockProbability == 0.35)
        #expect(first.blockMinRunLength == 3)
        #expect(first.colorAffinity == 1)
        #expect(first.spawnOnClear == false)
    }

    @Test("no round is easier than the classic baseline")
    func noneEasierThanBaseline() {
        let base = levels[0]
        for level in levels {
            #expect(level.blockProbability >= base.blockProbability)
            #expect(level.colorAffinity <= base.colorAffinity)
            #expect(level.colors >= base.colors)
            #expect(level.spawnCount >= base.spawnCount)
            #expect(level.startCount >= base.startCount)
            // What matters for preview is the *share* of the spawn revealed,
            // not the raw count: round 4 previews 4 of 4, which is more
            // marbles shown than the baseline's 3 but exactly as much
            // information.
            let share = Double(level.previewCount) / Double(level.spawnCount)
            let baseShare = Double(base.previewCount) / Double(base.spawnCount)
            #expect(share <= baseShare)
        }
    }

    @Test("clearing a line buys a free turn in every round but the last")
    func freeTurnUntilTheEnd() {
        for i in 0..<(levelCount - 1) {
            #expect(levels[i].spawnOnClear == false)
        }
        #expect(levels[levelCount - 1].spawnOnClear == true)
    }
}

@Suite("getLevel")
struct GetLevelTests {

    @Test("returns the requested level")
    func returnsRequested() {
        #expect(getLevel(2) == levels[2])
    }

    @Test("clamps out-of-range indices instead of trapping")
    func clampsOutOfRange() {
        #expect(getLevel(-5) == levels[0])
        #expect(getLevel(levelCount + 10) == levels[levelCount - 1])
    }
}

@Suite("isFinalLevel")
struct IsFinalLevelTests {

    @Test("only the last index ends the run")
    func onlyTheLast() {
        #expect(!isFinalLevel(0))
        #expect(!isFinalLevel(levelCount - 2))
        #expect(isFinalLevel(levelCount - 1))
    }
}
