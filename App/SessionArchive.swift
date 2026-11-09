import Foundation
import Observation

// MARK: - 課金の準備

/// 将来、有料にするかもしれない機能。
/// 課金を入れるときは FeatureAccess.isUnlocked の中身だけを StoreKit の購入状態に差し替える。
enum PremiumFeature {
    /// 実戦の履歴を保存・閲覧する
    case sessionHistory
    /// スペック表との比較（近い設定の表示）
    case specComparison
    /// 設定推測
    case settingEstimate
}

enum FeatureAccess {
    /// 今は全機能を無料で使える
    static func isUnlocked(_ feature: PremiumFeature) -> Bool {
        true
    }
}

// MARK: - 集計

/// 1機種ぶんのデータから、画面に出す数字を計算する（実戦中と履歴の両方で使う）
struct PlayStats {
    let machine: Machine
    let data: CounterData

    var games: Int { data.games }

    var jugglerModel: JugglerModel? {
        machine == .juggler ? (data.jugglerModel ?? .defaultModel) : nil
    }

    var bonuses: [BonusRecord] { data.bonuses ?? [] }

    func count(_ role: Role) -> Int {
        data.counts[role.rawValue, default: 0]
    }

    func bonusCount(_ kind: Role, _ overlap: BonusOverlap) -> Int {
        bonuses.filter { $0.kind == kind && $0.overlap == overlap }.count
    }

    var bonusTotal: Int { count(.big) + count(.reg) }

    func probability(_ count: Int) -> String {
        Probability.text(games: games, count: count)
    }

    /// スペック表で一番近い設定（ジャグラーのみ）
    func nearest(_ metric: SpecMetric, count: Int) -> String? {
        guard FeatureAccess.isUnlocked(.specComparison),
              let model = jugglerModel, games > 0, count > 0,
              model.hasSettingDifference(metric)
        else { return nil }
        let observed = Double(games) / Double(count)
        let label = JugglerModel.settingsLabel(model.nearestSettings(metric, observed: observed))
        return label.isEmpty ? nil : label
    }

    /// 小役の行に出す「設定N付近」（ぶどう・チェリーのみ。設定差がない機種は出さない）
    func nearest(for role: Role) -> String? {
        switch role {
        case .grape: nearest(.grape, count: count(.grape))
        case .cherry: nearest(.cherry, count: count(.cherry))
        default: nil
        }
    }

    /// 各ボーナスの、前のボーナス（最初は打ち始め）からのG数
    var gamesBetweenBonuses: [UUID: Int] {
        var result: [UUID: Int] = [:]
        var previous = data.startTotal
        for record in bonuses {
            if let total = record.totalGames, let previous {
                result[record.id] = max(0, total - previous)
            }
            previous = record.totalGames
        }
        return result
    }
}

// MARK: - 実戦の履歴

/// 保存した1回ぶんの実戦
struct SessionRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var savedAt: Date
    var storeName: String
    /// 台番（文字で持つ。「123」「A-12」など）
    var machineNumber: String
    var machine: Machine
    var data: CounterData

    var stats: PlayStats { PlayStats(machine: machine, data: data) }

    var machineTitle: String {
        if machine == .juggler {
            return (data.jugglerModel ?? .defaultModel).label
        }
        return machine.label
    }
}

/// 実戦の履歴の保存先（Application Support/sessions.json）
@MainActor
@Observable
final class SessionArchive {
    static let shared = SessionArchive()

    private static let lastStoreKey = "sessionArchive.lastStoreName"

    /// 新しい順
    private(set) var sessions: [SessionRecord] = []

    var lastStoreName: String {
        get { UserDefaults.standard.string(forKey: Self.lastStoreKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastStoreKey) }
    }

    private init() {
        load()
    }

    func add(_ record: SessionRecord) {
        sessions.insert(record, at: 0)
        lastStoreName = record.storeName
        save()
    }

    func delete(_ ids: [UUID]) {
        sessions.removeAll { ids.contains($0.id) }
        save()
    }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "sessions.json")
    }

    private func load() {
        guard
            let stored = try? Data(contentsOf: Self.fileURL),
            let decoded = try? JSONDecoder().decode([SessionRecord].self, from: stored)
        else { return }
        sessions = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        try? FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory,
            withIntermediateDirectories: true
        )
        try? encoded.write(
            to: Self.fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
