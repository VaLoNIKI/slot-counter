import ActivityKit
import Foundation
import Observation

/// UserDefaults に保存するカウントデータ
struct CounterData: Codable, Equatable {
    /// Role.rawValue -> 回数
    var counts: [String: Int] = [:]
    /// 取り消し用の操作履歴（新しいものが末尾）
    var history: [Role] = []
    var totalGames: Int = 0
}

/// カウントの唯一の保存先。
/// LiveActivityIntent はアプリのプロセスで実行されるため、App Groups なしの
/// UserDefaults.standard でアプリ画面とロック画面の操作が同じデータを共有できる。
@MainActor
@Observable
final class CounterModel {
    static let shared = CounterModel()

    private static let storageKey = "counterData.v1"
    private static let historyLimit = 1000

    private(set) var data: CounterData

    private init() {
        data = Self.load()
    }

    func count(_ role: Role) -> Int {
        data.counts[role.rawValue, default: 0]
    }

    var totalGames: Int { data.totalGames }

    var canUndo: Bool { !data.history.isEmpty }

    func increment(_ role: Role) {
        data.counts[role.rawValue, default: 0] += 1
        data.history.append(role)
        if data.history.count > Self.historyLimit {
            data.history.removeFirst(data.history.count - Self.historyLimit)
        }
        save()
    }

    func undo() {
        guard let last = data.history.popLast() else { return }
        data.counts[last.rawValue] = max(0, data.counts[last.rawValue, default: 0] - 1)
        save()
    }

    func setTotalGames(_ games: Int) {
        data.totalGames = max(0, games)
        save()
    }

    func reset() {
        data = CounterData()
        save()
    }

    func reloadFromDisk() {
        data = Self.load()
    }

    var contentState: SlotCounterAttributes.ContentState {
        .init(counts: data.counts, totalGames: data.totalGames, canUndo: canUndo)
    }

    /// 表示中のライブアクティビティを現在の値で更新する
    func syncLiveActivities() async {
        let state = contentState
        for activity in Activity<SlotCounterAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }

    private static func load() -> CounterData {
        guard
            let stored = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(CounterData.self, from: stored)
        else { return CounterData() }
        return decoded
    }
}
