/// Tuning constants for the game. Mirrors `src/game/constants.ts` in the web
/// repo, minus the CSS layout values (`CELL_SIZE_PX` and friends) — SwiftUI
/// does its own layout, so there is nothing here for the view to match.
public enum Marmor {
    /// Board is `size` x `size`.
    public static let size = 9

    /// Number of distinct marble colors.
    public static let colors = 7

    /// Marbles needed in a row before a line pops.
    public static let lineMin = 5

    /// Marbles that drop each turn the player fails to clear a line.
    public static let spawnCount = 3

    /// The King's fixed score — the Pretender wins by reaching or beating it.
    public static let kingScore = 100

    /// A spawn only blocks the player's most advanced line once it's at least this long.
    public static let blockMinRunLength = 3

    /// Chance, per non-initial spawn, that blocking is even considered this turn.
    /// A flat probability rather than a fixed cooldown so it doesn't fall into
    /// an obvious every-Nth-turn pattern.
    public static let blockProbability = 0.35
}
