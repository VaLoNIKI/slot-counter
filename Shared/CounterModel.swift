import ActivityKit
import Foundation
import Observation

/// 保存するカウントデータ
struct CounterData: Codable, Equatable {
    /// Role.rawValue -> 回数
    var counts: [String: Int] = [:]
    /// 取り消し用の操作履歴（新しいものが末尾）
    var history: [Role] = []
    var totalGames: Int = 0
    /// 直前の操作の表示用テキスト（古い保存データには無いので Optional）
    var lastAction: String?
}

/// カウントの唯一の保存先。
/// コントロールの Intent は LiveActivityIntent なのでアプリのプロセスで実行される。
/// そのため App Groups なしでも、アプリ画面とコントロールが同じファイルを共有できる。
///
/// 保存先は Application Support/counter.json。保護レベルは
/// completeFileProtectionUntilFirstUserAuthentication（再起動後の初回ロック解除以降は、
/// ロック中でも読み書きできる）。
@MainActor
@Observable
final class CounterModel {
    static let shared = CounterModel()

    private static let historyLimit = 1000
    private static let legacyDefaultsKey = "counterData.v1"

    private(set) var data: CounterData
    /// ファイルはあるのに読めなかった（初回ロック解除前など）。
    /// この状態で書き込むとデータを空で上書きしてしまうので、読めるまで変更しない。
    private var isUnreadable = false

    private init() {
        data = CounterData()
        reloadFromDisk()
    }

    func count(_ role: Role) -> Int {
        data.counts[role.rawValue, default: 0]
    }

    var totalGames: Int { data.totalGames }

    var canUndo: Bool { !data.history.isEmpty }

    func increment(_ role: Role) {
        guard ensureReadable() else { return }
        data.counts[role.rawValue, default: 0] += 1
        data.history.append(role)
        if data.history.count > Self.historyLimit {
            data.history.removeFirst(data.history.count - Self.historyLimit)
        }
        data.lastAction = "\(role.label) +1"
        save()
    }

    func undo() {
        guard ensureReadable() else { return }
        guard let last = data.history.popLast() else { return }
        data.counts[last.rawValue] = max(0, data.counts[last.rawValue, default: 0] - 1)
        data.lastAction = "取消 \(last.label)"
        save()
    }

    func setTotalGames(_ games: Int) {
        guard ensureReadable() else { return }
        data.totalGames = max(0, games)
        save()
    }

    func reset() {
        data = CounterData()
        isUnreadable = false
        save()
    }

    func reloadFromDisk() {
        switch Self.load() {
        case .loaded(let loaded):
            data = loaded
            isUnreadable = false
        case .missing:
            if let migrated = Self.loadLegacyDefaults() {
                data = migrated
                isUnreadable = false
                save()
                UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
            } else {
                isUnreadable = false
            }
        case .unreadable:
            isUnreadable = true
        }
    }

    var contentState: SlotCounterAttributes.ContentState {
        .init(
            counts: data.counts,
            totalGames: data.totalGames,
            canUndo: canUndo,
            lastAction: data.lastAction
        )
    }

    /// 表示中のライブアクティビティを現在の値で更新する
    func syncLiveActivities() async {
        let state = contentState
        for activity in Activity<SlotCounterAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    // MARK: - Storage

    private enum LoadResult {
        case loaded(CounterData)
        case missing
        case unreadable
    }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "counter.json")
    }

    private func ensureReadable() -> Bool {
        if isUnreadable { reloadFromDisk() }
        return !isUnreadable
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        do {
            try FileManager.default.createDirectory(
                at: URL.applicationSupportDirectory,
                withIntermediateDirectories: true
            )
            try encoded.write(
                to: Self.fileURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch {
            // 書けなかった場合はメモリ上の値だけ進む。次回の保存で再度書き込む。
        }
    }

    private static func load() -> LoadResult {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return .missing
        }
        guard
            let stored = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(CounterData.self, from: stored)
        else { return .unreadable }
        return .loaded(decoded)
    }

    /// 旧バージョン（UserDefaults 保存）からの引き継ぎ
    private static func loadLegacyDefaults() -> CounterData? {
        guard let stored = UserDefaults.standard.data(forKey: legacyDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(CounterData.self, from: stored)
    }
}
