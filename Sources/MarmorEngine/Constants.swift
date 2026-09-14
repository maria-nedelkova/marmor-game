/// Tuning constants for the game. Mirrors `src/game/constants.ts` in the web
/// repo, minus the CSS layout values (`CELL_SIZE_PX` and friends) — SwiftUI
/// does its own layout, so there is nothing here for the view to match.
public enum Marmor {
    /// Board is `size` x `size`.
    public static let size = 9

    /// Palette size — the number of marble colors the renderer defines. How
    /// many are actually in play is per-level (`LevelConfig.colors`); this is
    /// the ceiling, not the game setting. The classic game (and round 1) uses
    /// the first seven; the eighth exists only for the later rounds.
    public static let colors = 8

    /// Marbles needed in a row before a line pops.
    public static let lineMin = 5

    /// The King's score, in every round. Deliberately a constant rather than a
    /// per-level field: the target never varies, so the ladder gets harder by
    /// making 100 points harder to reach, not by moving the finish line.
    public static let kingScore = 100
}
