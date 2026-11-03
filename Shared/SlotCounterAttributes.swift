import ActivityKit

struct SlotCounterAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Role.rawValue -> 回数
        var counts: [String: Int]
        var totalGames: Int
        var canUndo: Bool

        func count(_ role: Role) -> Int {
            counts[role.rawValue, default: 0]
        }

        var total: Int {
            counts.values.reduce(0, +)
        }
    }
}
