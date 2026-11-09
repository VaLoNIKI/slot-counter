import ActivityKit

struct SlotCounterAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        struct Item: Codable, Hashable, Identifiable {
            /// Role.rawValue
            var roleID: String
            var count: Int

            var id: String { roleID }
            var role: Role? { Role(rawValue: roleID) }
        }

        var machineName: String
        /// 選択中の機種の項目（表示順）
        var items: [Item]
        var totalGames: Int
        var canUndo: Bool
        /// 直前の操作（例: "ブドウ +1" / "取消 BIG"）。押せたかの確認用
        var lastAction: String?
        /// BIG+REG の回数（ボーナスがある機種のみ）
        var bonusTotal: Int?
        /// 最後のボーナスからのG数（総回転数を入れているときのみ）
        var sinceLastBonus: Int?

        var total: Int {
            items.reduce(0) { $0 + $1.count }
        }

        func count(_ role: Role) -> Int? {
            items.first { $0.roleID == role.rawValue }?.count
        }
    }
}
