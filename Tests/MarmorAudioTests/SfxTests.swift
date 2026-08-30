import Foundation
import Testing

@testable import MarmorAudio

@Suite("Sfx")
struct SfxTests {

    func seconds(_ samples: [Float]) -> Double {
        Double(samples.count) / defaultSampleRate
    }

    func peakLevel(_ samples: some Collection<Float>) -> Float {
        samples.map(\.magnitude).max() ?? 0
    }

    /// Every effect, so the shared invariants can be checked in one place.
    func allEffects() -> [(String, [Float])] {
        var rng = SeededGenerator(seed: 99)
        return [
            ("select", Sfx.select()),
            ("glideTick", Sfx.glideTick()),
            ("place", Sfx.place(using: &rng)),
            ("clear5", Sfx.clear(lineLength: 5)),
            ("clear9", Sfx.clear(lineLength: 9)),
            ("win", Sfx.win()),
            ("pretenderBoo", Sfx.pretenderBoo()),
            ("kingFall", Sfx.kingFall()),
        ]
    }

    @Test("every effect produces finite, clamped, audible output")
    func wellFormed() {
        for (name, samples) in allEffects() {
            #expect(!samples.isEmpty, "\(name) is empty")
            #expect(samples.allSatisfy { $0.isFinite }, "\(name) has NaN or infinity")
            #expect(samples.allSatisfy { abs($0) <= 1 }, "\(name) clips")
            #expect(peakLevel(samples) > 0.01, "\(name) is inaudible")
        }
    }

    @Test("every effect starts from silence")
    func startsFromSilence() {
        for (name, samples) in allEffects() {
            #expect(abs(samples[0]) < 0.01, "\(name) starts with a click")
        }
    }

    @Test("short effects are short")
    func shortEffectDurations() {
        #expect(abs(seconds(Sfx.select()) - 0.055) < 0.002)
        #expect(abs(seconds(Sfx.glideTick()) - 0.035) < 0.002)
    }

    @Test("place mixes a noise burst into the blip")
    func placeIsBlipPlusNoise() {
        var rng = SeededGenerator(seed: 5)
        let place = Sfx.place(using: &rng)
        let blipOnly = renderBlip(
            frequency: 300, duration: 0.06, waveform: .square, peak: 0.14, sweepTo: 220)

        // Same length — the blip outlasts the 0.04s burst — but different content.
        #expect(place.count == blipOnly.count)
        #expect(place != blipOnly)
    }

    @Test("longer lines get a longer, fuller clear chime")
    func clearScalesWithLineLength() {
        #expect(seconds(Sfx.clear(lineLength: 9)) > seconds(Sfx.clear(lineLength: 5)))
    }

    @Test("clear chime voice count never runs away")
    func clearVoicesAreCapped() {
        // Voices cap at 8, which is reached by length 15 — unreachable on a
        // 9x9 board, but the cap should hold regardless.
        #expect(Sfx.clear(lineLength: 15).count == Sfx.clear(lineLength: 100).count)
    }

    @Test("clear length is non-decreasing in line length")
    func clearMonotonic() {
        let lengths = (5...9).map { Sfx.clear(lineLength: $0).count }
        #expect(zip(lengths, lengths.dropFirst()).allSatisfy { $0.0 <= $0.1 })
    }

    @Test("win fanfare runs about two thirds of a second")
    func winDuration() {
        #expect(abs(seconds(Sfx.win()) - 0.645) < 0.005)
    }

    @Test("the boo runs the full 0.9 seconds")
    func booDuration() {
        #expect(abs(seconds(Sfx.pretenderBoo()) - 0.9) < 0.005)
    }

    @Test("the boo swells rather than starting at full volume")
    func booSwells() {
        let boo = Sfx.pretenderBoo()
        let window = boo.count / 10
        let opening = peakLevel(boo[0..<window])
        let sustain = peakLevel(boo[(boo.count / 3)..<(boo.count / 2)])
        #expect(sustain > opening)
    }

    @Test("the king's fall lands a thud at the end")
    func kingFallEndsWithThud() {
        let fall = Sfx.kingFall()
        // The spring wobble has decayed to near nothing by 0.9s, so anything
        // audible in the last tenth is the thud.
        let tail = fall[(fall.count * 9 / 10)...]
        #expect(peakLevel(tail) > 0.05)
        #expect(abs(seconds(fall) - 1.025) < 0.005)
    }
}
