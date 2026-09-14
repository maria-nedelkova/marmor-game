import Testing

@testable import MarmorEngine

private func makeRun(
    id: String = "p",
    name: String = "P",
    roundsCleared: Int = 0,
    partialPoints: Int = 0,
    moves: Int = 100,
    score: Int = 0,
    at: Int = 1
) -> RunEntry {
    RunEntry(
        id: id, name: name, roundsCleared: roundsCleared, partialPoints: partialPoints,
        moves: moves, score: score, at: at)
}

@Suite("progress")
struct ProgressTests {

    @Test("a finished run is exactly maxProgress, whatever the score was")
    func finishersLandOnMax() {
        let lucky = makeRun(roundsCleared: levelCount, score: 880)
        let tidy = makeRun(roundsCleared: levelCount, score: 803)
        #expect(lucky.progress == maxProgress)
        #expect(tidy.progress == maxProgress)
    }

    @Test("an unfinished run counts 100 a round plus what it banked in the last")
    func partialRun() {
        #expect(makeRun(roundsCleared: 5, partialPoints: 45).progress == 545)
    }

    @Test("overshoot can't inflate progress — the whole point of the metric")
    func overshootIgnored() {
        // Same depth, wildly different raw scores because of final-clear length.
        let a = makeRun(roundsCleared: 3, partialPoints: 20, score: 340)
        let b = makeRun(roundsCleared: 3, partialPoints: 20, score: 395)
        #expect(a.progress == b.progress)
    }

    @Test("a corrupt entry can't buy an extra round")
    func corruptEntriesClamped() {
        #expect(makeRun(roundsCleared: 2, partialPoints: 5_000).progress == 299)
        #expect(makeRun(roundsCleared: 999).progress == maxProgress)
        #expect(makeRun(roundsCleared: -3, partialPoints: -9).progress == 0)
    }
}

@Suite("ranking")
struct RankingTests {

    @Test("finishers are ordered by moves, not by score")
    func movesBeatScore() {
        let lena = makeRun(id: "lena", roundsCleared: levelCount, moves: 198, score: 812)
        let maria = makeRun(id: "maria", roundsCleared: levelCount, moves: 204, score: 861)
        #expect(rankEntries([maria, lena]).map(\.id) == ["lena", "maria"])
    }

    @Test("every finisher outranks every non-finisher")
    func finishersFirst() {
        let slowFinisher = makeRun(id: "fin", roundsCleared: levelCount, moves: 9_000)
        let fastQuitter = makeRun(
            id: "quit", roundsCleared: levelCount - 1, partialPoints: 99, moves: 1)
        #expect(rankEntries([fastQuitter, slowFinisher]).map(\.id) == ["fin", "quit"])
    }

    @Test("among non-finishers, depth beats efficiency")
    func depthBeatsEfficiency() {
        let deeper = makeRun(id: "deep", roundsCleared: 5, partialPoints: 0, moves: 900)
        let tidier = makeRun(id: "tidy", roundsCleared: 4, partialPoints: 99, moves: 10)
        #expect(rankEntries([tidier, deeper]).map(\.id) == ["deep", "tidy"])
    }

    @Test("identical runs keep the earlier one first")
    func earlierWinsTies() {
        let first = makeRun(id: "a", at: 100)
        let second = makeRun(id: "b", at: 200)
        #expect(rankEntries([second, first]).map(\.id) == ["a", "b"])
    }

    @Test("ranking is a consistent total order over a mixed field")
    func totalOrder() {
        let field = [
            makeRun(id: "a", roundsCleared: levelCount, moves: 251),
            makeRun(id: "b", roundsCleared: levelCount, moves: 198),
            makeRun(id: "c", roundsCleared: 6, partialPoints: 88, moves: 203),
            makeRun(id: "d", roundsCleared: 6, partialPoints: 88, moves: 190),
            makeRun(id: "e", roundsCleared: 0, partialPoints: 0, moves: 4),
        ]
        let ranked = rankEntries(field).map(\.id)
        #expect(ranked == ["b", "a", "d", "c", "e"])
        // Sorting an already-sorted list must not reshuffle it.
        #expect(rankEntries(rankEntries(field)).map(\.id) == ranked)
    }
}

@Suite("sortKey")
struct SortKeyTests {

    @Test("more moves always lowers the key, never raises it")
    func movesLowerTheKey() {
        let fast = makeRun(roundsCleared: 4, moves: 50)
        let slow = makeRun(roundsCleared: 4, moves: 51)
        #expect(fast.sortKey > slow.sortKey)
    }

    @Test("a move count beyond the cap can't wrap into a better key")
    func cappedMoves() {
        let capped = makeRun(roundsCleared: 4, moves: 99_999)
        let absurd = makeRun(roundsCleared: 4, moves: 10_000_000)
        #expect(absurd.sortKey == capped.sortKey)
        #expect(absurd.sortKey < makeRun(roundsCleared: 4, moves: 0).sortKey)
    }

    @Test("one extra point of progress outweighs any move saving")
    func progressDominatesMoves() {
        let deeperButSlow = makeRun(roundsCleared: 4, partialPoints: 1, moves: 99_999)
        let shallowerButFast = makeRun(roundsCleared: 4, partialPoints: 0, moves: 0)
        #expect(deeperButSlow.sortKey > shallowerButFast.sortKey)
    }
}

@Suite("isBetter")
struct IsBetterTests {

    @Test("keeps the better of two attempts by the same player")
    func picksTheBetterRun() {
        let previous = makeRun(roundsCleared: 3, partialPoints: 10, moves: 200)
        #expect(makeRun(roundsCleared: 4, moves: 400).isBetter(than: previous))
        #expect(makeRun(roundsCleared: 3, partialPoints: 10, moves: 199).isBetter(than: previous))
        #expect(!makeRun(roundsCleared: 3, partialPoints: 10, moves: 201).isBetter(than: previous))
        #expect(!previous.isBetter(than: previous))
    }
}

@Suite("reachedLabel")
struct ReachedLabelTests {

    @Test("finished runs show the full ladder")
    func finished() {
        #expect(makeRun(roundsCleared: levelCount).reachedLabel == "\(levelCount)/\(levelCount)")
    }

    @Test("unfinished runs name the round they died in, 1-indexed")
    func unfinished() {
        #expect(makeRun(roundsCleared: 5, partialPoints: 45).reachedLabel == "R6 · 45")
        #expect(makeRun(roundsCleared: 0, partialPoints: 0).reachedLabel == "R1 · 0")
    }
}

@Suite("isFinisher")
struct IsFinisherTests {

    @Test("only a full ladder counts")
    func fullLadderOnly() {
        #expect(makeRun(roundsCleared: levelCount).isFinisher)
        #expect(!makeRun(roundsCleared: levelCount - 1, partialPoints: 99).isFinisher)
    }
}
