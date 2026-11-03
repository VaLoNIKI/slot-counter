import ActivityKit
import Foundation
import Observation

/// 1機種ぶんのカウントデータ
struct CounterData: Codable, Equatable {
    /// Role.rawValue -> 回数
    var counts: [String: Int] = [:]
    /// 取り消し用の操作履歴（新しいものが末尾）
    var history: [Role] = []
    var totalGames: Int = 0
    /// 直前の操作の表示用テキスト（古い保存データには無いので Optional）
    var lastAction: String?
}

/// 保存ファイルの中身（機種ごとのカウント + 選択中の機種）
struct CounterStore: Codable, Equatable {
    var selected: Machine = .generic
    /// Machine.rawValue -> その機種のカウント
    var machines: [String: CounterData] = [:]
}

/// カウントの唯一の保存先。
/// コントロールやライブアクティビティのボタンの Intent は LiveActivityIntent なので
/// アプリのプロセスで実行される。そのため App Groups なしでも、アプリ画面と同じファイルを共有できる。
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

    private(set) var store: CounterStore
    /// ファイルはあるのに読めなかった（初回ロック解除前など）。
    /// この状態で書き込むとデータを空で上書きしてしまうので、読めるまで変更しない。
    private var isUnreadable = false

    private init() {
        store = CounterStore()
        reloadFromDisk()
    }

    // MARK: - 読み取り

    var selectedMachine: Machine { store.selected }

    /// 選択中の機種のデータ
    var current: CounterData {
        store.machines[store.selected.rawValue] ?? CounterData()
    }

    func count(_ role: Role) -> Int {
        current.counts[role.rawValue, default: 0]
    }

    var totalGames: Int { current.totalGames }

    var canUndo: Bool { !current.history.isEmpty }

    /// BIG+REG（ボーナスがある機種のみ）
    var bonusTotal: Int? {
        selectedMachine.hasBonus ? count(.big) + count(.reg) : nil
    }

    // MARK: - 変更

    func selectMachine(_ machine: Machine) {
        guard ensureReadable(), machine != store.selected else { return }
        store.selected = machine
        save()
    }

    func increment(_ role: Role) {
        guard ensureReadable() else { return }
        let machine = store.selected
        guard machine.roles.contains(role) else {
            // 今の機種に無い項目のコントロールが押された
            updateCurrent { $0.lastAction = "\(machine.label)に\(role.label)はありません" }
            return
        }
        updateCurrent { data in
            data.counts[role.rawValue, default: 0] += 1
            data.history.append(role)
            if data.history.count > Self.historyLimit {
                data.history.removeFirst(data.history.count - Self.historyLimit)
            }
            data.lastAction = "\(role.label) +1"
        }
    }

    func undo() {
        guard ensureReadable(), canUndo else { return }
        updateCurrent { data in
            guard let last = data.history.popLast() else { return }
            data.counts[last.rawValue] = max(0, data.counts[last.rawValue, default: 0] - 1)
            data.lastAction = "取消 \(last.label)"
        }
    }

    func setTotalGames(_ games: Int) {
        guard ensureReadable() else { return }
        updateCurrent { $0.totalGames = max(0, games) }
    }

    /// 選択中の機種のカウントと総G数だけをリセットする
    func resetCurrentMachine() {
        guard ensureReadable() else { return }
        store.machines[store.selected.rawValue] = CounterData()
        save()
    }

    func reloadFromDisk() {
        switch Self.load() {
        case .loaded(let loaded):
            store = loaded
            isUnreadable = false
        case .migrated(let migrated):
            store = migrated
            isUnreadable = false
            save()
        case .missing:
            isUnreadable = false
            if let legacy = Self.loadLegacyDefaults() {
                store = CounterStore(selected: .generic, machines: [Machine.generic.rawValue: legacy])
                save()
                UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
            }
        case .unreadable:
            isUnreadable = true
        }
    }

    // MARK: - ライブアクティビティ

    var contentState: SlotCounterAttributes.ContentState {
        let machine = selectedMachine
        return .init(
            machineName: machine.label,
            items: machine.roles.map { .init(roleID: $0.rawValue, count: count($0)) },
            totalGames: totalGames,
            canUndo: canUndo,
            lastAction: current.lastAction,
            bonusTotal: bonusTotal
        )
    }

    /// Intent 用：+1 してライブアクティビティを更新する
    func incrementAndSync(_ role: Role) async {
        increment(role)
        await syncLiveActivities()
    }

    /// Intent 用：取り消してライブアクティビティを更新する
    func undoAndSync() async {
        undo()
        await syncLiveActivities()
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
        case loaded(CounterStore)
        /// 旧形式（1機種ぶんだけのファイル）を変換した
        case migrated(CounterStore)
        case missing
        case unreadable
    }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "counter.json")
    }

    private func updateCurrent(_ change: (inout CounterData) -> Void) {
        var data = current
        change(&data)
        store.machines[store.selected.rawValue] = data
        save()
    }

    private func ensureReadable() -> Bool {
        if isUnreadable { reloadFromDisk() }
        return !isUnreadable
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(store) else { return }
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
        guard let stored = try? Data(contentsOf: url) else { return .unreadable }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(CounterStore.self, from: stored) {
            return .loaded(decoded)
        }
        // 旧形式: 汎用の4項目だけを保存していた
        if let old = try? decoder.decode(CounterData.self, from: stored) {
            return .migrated(CounterStore(selected: .generic, machines: [Machine.generic.rawValue: old]))
        }
        // 読めたが中身が壊れている。読めない扱いにすると二度と書けなくなるので、新規扱いにする
        return .missing
    }

    /// さらに古いバージョン（UserDefaults 保存）からの引き継ぎ
    private static func loadLegacyDefaults() -> CounterData? {
        guard let stored = UserDefaults.standard.data(forKey: legacyDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(CounterData.self, from: stored)
    }
}
