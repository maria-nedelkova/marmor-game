import AVFoundation
import Foundation

/// Plays the synthesized effects through AVAudioEngine.
///
/// Each effect is rendered once into a PCM buffer and cached, then replayed
/// through a small pool of player nodes so overlapping sounds — a glide tick
/// landing on top of a clear chime — don't cut each other off. Nothing is
/// loaded from disk; there are no audio assets in the bundle.
@MainActor
public final class SoundPlayer {

    public static let shared = SoundPlayer()

    /// Silences playback. Buffers stay cached, so unmuting is instant.
    public var isMuted = false

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(
        standardFormatWithSampleRate: defaultSampleRate, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var isRunning = false
    private var cache: [Effect: AVAudioPCMBuffer] = [:]
    private var rng = SystemRandomNumberGenerator()

    /// How many sounds can overlap before the oldest node gets reused.
    private static let voiceCount = 12

    private enum Effect: Hashable {
        case select
        case glideTick
        case place
        case win
        case pretenderBoo
        case kingFall
        case clear(lineLength: Int)
    }

    private init() {}

    // MARK: - Lifecycle

    /// Starts the audio engine and configures the session. Safe to call
    /// repeatedly; only the first call does work.
    ///
    /// The web version needs this because browsers block autoplay until a user
    /// gesture. iOS has no such rule, but calling it early still avoids the
    /// engine spinning up in the middle of the first move.
    public func prime() {
        guard !isRunning else { return }

        #if os(iOS)
            // `.ambient` respects the silent switch and mixes with whatever the
            // player already has going — a puzzle game shouldn't stop someone's
            // music.
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
        #endif

        for _ in 0..<Self.voiceCount {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }

        do {
            try engine.start()
        } catch {
            // No audio device, or the session was denied. The game stays
            // playable; it just runs silent.
            return
        }

        for node in players { node.play() }
        isRunning = true
    }

    /// Renders and caches every effect up front, so no sound pays synthesis
    /// cost on its first play. Line-clear chimes are rendered for every legal
    /// line length.
    /// - Parameter clearLineLengths: the line lengths to pre-render clear
    ///   chimes for. Defaults to every length that can clear on a 9x9 board.
    public func preload(clearLineLengths: ClosedRange<Int> = 5...9) {
        for length in clearLineLengths { _ = buffer(for: .clear(lineLength: length)) }
        for effect in [Effect.select, .glideTick, .place, .win, .pretenderBoo, .kingFall] {
            _ = buffer(for: effect)
        }
    }

    // MARK: - Effects

    /// Marble picked up / selected.
    public func playSelect() { play(.select) }

    /// A single glide step while a marble travels its path.
    public func playGlideTick() { play(.glideTick) }

    /// Marble settles into its destination (or a spawn lands).
    public func playPlace() { play(.place) }

    /// Line clear — voice count and pitch scale with the line length.
    public func playClear(lineLength: Int) { play(.clear(lineLength: lineLength)) }

    /// Win — the Pretender dethrones the King.
    public func playWin() { play(.win) }

    /// The Pretender topples when the table fills up.
    public func playPretenderBoo() { play(.pretenderBoo) }

    /// The King tumbles when the Pretender dethrones him.
    public func playKingFall() { play(.kingFall) }

    // MARK: - Plumbing

    private func play(_ effect: Effect) {
        guard !isMuted else { return }
        prime()
        guard isRunning, let buffer = buffer(for: effect) else { return }

        let node = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    private func buffer(for effect: Effect) -> AVAudioPCMBuffer? {
        if let cached = cache[effect] { return cached }

        let samples: [Float]
        switch effect {
        case .select: samples = Sfx.select()
        case .glideTick: samples = Sfx.glideTick()
        case .place: samples = Sfx.place(using: &rng)
        case .win: samples = Sfx.win()
        case .pretenderBoo: samples = Sfx.pretenderBoo()
        case .kingFall: samples = Sfx.kingFall()
        case .clear(let lineLength): samples = Sfx.clear(lineLength: lineLength)
        }

        guard let buffer = Self.pcmBuffer(samples, format: format) else { return nil }
        cache[effect] = buffer
        return buffer
    }

    private static func pcmBuffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel[0].update(from: source.baseAddress!, count: samples.count)
        }
        return buffer
    }
}
