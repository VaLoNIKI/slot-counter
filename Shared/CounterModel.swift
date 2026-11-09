import ActivityKit
import Foundation
import Observation

/// ボーナスの重複（ジャグラー）
enum BonusOverlap: String, Codable, CaseIterable, Identifiable {
    /// 単独
    case alone
    /// チェリー重複
    case cherry
    /// 区別していない（ロック画面やコントロールから記録したとき）
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alone: "単独"
        case .cherry: "チェリー"
        case .unknown: "不明"
        }
    }
}

/// 1回ぶんのボーナスの記録
struct BonusRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// .big か .reg
    var kind: Role
    /// 重複の区別（ジャグラーのみ。ハナハナなどは nil）
    var overlap: BonusOverlap?
    /// 当選時のデータカウンターの総回転数（入力しなかったら nil）
    var totalGames: Int?
    var date: Date = Date()

    var label: String {
        if let overlap, overlap != .unknown {
            return "\(overlap.label)\(kind.label)"
        }
        return kind.label
    }
}

/// 1機種ぶんのカウントデータ。
/// 古い保存データも読めるよう、後から足した項目はすべて Optional にしている。
struct CounterData: Codable, Equatable {
    /// Role.rawValue -> 回数
    var counts: [String: Int] = [:]
    /// 取り消し用の操作履歴（新しいものが末尾）
    var history: [Role] = []
    /// 旧版の手入力の総G数。打ち始め／現在の総回転数が入っていればそちらを使う
    var totalGames: Int = 0
    /// 直前の操作の表示用テキスト
    var lastAction: String?
    /// ロック画面の再生ボタン（次の曲／前の曲）に割り当てた項目。nil なら機種の初期値
    var nextTrackRole: Role?
    var previousTrackRole: Role?
    /// データカウンターの総回転数：打ち始め
    var startTotal: Int?
    /// データカウンターの総回転数：現在
    var currentTotal: Int?
    /// ボーナスの記録（古い順）
    var bonuses: [BonusRecord]?
    /// ジャグラーの機種
    var jugglerModel: JugglerModel?

    /// 自分が回したG数
    var games: Int {
        if startTotal != nil || currentTotal != nil {
            let start = startTotal ?? 0
            return max(0, (currentTotal ?? start) - start)
        }
        return totalGames
    }

    /// 最後のボーナス（なければ打ち始め）からのG数。
    /// 最後のボーナスの総回転数が分からないときは、古いボーナスから数えると誤るので nil
    var sinceLastBonus: Int? {
        guard let currentTotal else { return nil }
        let base: Int?
        if let last = bonuses?.last {
            base = last.totalGames
        } else {
            base = startTotal
        }
        guard let base else { return nil }
        return max(0, currentTotal - base)
    }
}

/// 保存ファイルの中身（機種ごとのカウント + 選択中の機種）
struct CounterStore: Codable, Equatable {
    static let currentSchemaVersion = 3

    var selected: Machine = .generic
    /// Machine.rawValue -> その機種のカウント
    var machines: [String: CounterData] = [:]
    /// 保存形式の版。将来形式を変えたときの引き継ぎ用
    var schemaVersion: Int?
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
    /// 値が変わったとき（syncLiveActivities のたび）に呼ばれる。再生中表示の更新に使う
    @ObservationIgnored var onChange: (@MainActor () -> Void)?
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

    /// 自分が回したG数（確率の計算に使う）
    var totalGames: Int { current.games }

    /// 最後のボーナスからのG数（ハマり）
    var sinceLastBonus: Int? { current.sinceLastBonus }

    var bonuses: [BonusRecord] { current.bonuses ?? [] }

    var jugglerModel: JugglerModel { current.jugglerModel ?? .defaultModel }

    func bonusCount(_ kind: Role, overlap: BonusOverlap? = nil) -> Int {
        bonuses.filter { $0.kind == kind && (overlap == nil || $0.overlap == overlap) }.count
    }

    var canUndo: Bool { !current.history.isEmpty }

    /// BIG+REG（ボーナスがある機種のみ）
    var bonusTotal: Int? {
        selectedMachine.hasBonus ? count(.big) + count(.reg) : nil
    }

    /// ロック画面の「次の曲」ボタンで +1 する項目
    var nextTrackRole: Role {
        validRole(current.nextTrackRole) ?? selectedMachine.defaultNextTrackRole
    }

    /// ロック画面の「前の曲」ボタンで +1 する項目
    var previousTrackRole: Role {
        validRole(current.previousTrackRole) ?? selectedMachine.defaultPreviousTrackRole
    }

    private func validRole(_ role: Role?) -> Role? {
        guard let role, selectedMachine.roles.contains(role) else { return nil }
        return role
    }

    // MARK: - 変更

    func setNextTrackRole(_ role: Role) {
        guard ensureReadable() else { return }
        updateCurrent { $0.nextTrackRole = role }
    }

    func setPreviousTrackRole(_ role: Role) {
        guard ensureReadable() else { return }
        updateCurrent { $0.previousTrackRole = role }
    }

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
            Self.add(role, to: &data)
            if role == .big || role == .reg {
                // ロック画面やコントロールから押されたボーナスは、重複・G数なしで記録する（あとでアプリで直せる）
                data.bonuses = (data.bonuses ?? []) + [
                    BonusRecord(kind: role, overlap: machine == .juggler ? .unknown : nil, totalGames: nil)
                ]
            }
            data.lastAction = "\(role.label) +1"
        }
    }

    /// アプリの画面からボーナスを記録する（重複と当選時の総回転数つき）
    func recordBonus(_ kind: Role, overlap: BonusOverlap?, totalGames: Int?) {
        guard ensureReadable(), selectedMachine.roles.contains(kind) else { return }
        updateCurrent { data in
            Self.add(kind, to: &data)
            let record = BonusRecord(kind: kind, overlap: overlap, totalGames: totalGames)
            data.bonuses = (data.bonuses ?? []) + [record]
            if let totalGames, totalGames > (data.currentTotal ?? 0) {
                data.currentTotal = totalGames
            }
            data.lastAction = "\(record.label) +1"
        }
    }

    /// 記録済みのボーナスの重複・総回転数を直す
    func updateBonus(_ id: UUID, overlap: BonusOverlap?, totalGames: Int?) {
        guard ensureReadable() else { return }
        updateCurrent { data in
            guard let index = data.bonuses?.firstIndex(where: { $0.id == id }) else { return }
            data.bonuses?[index].overlap = overlap
            data.bonuses?[index].totalGames = totalGames
        }
    }

    /// 記録済みのボーナスを消す（回数も1減らす）
    func deleteBonus(_ id: UUID) {
        guard ensureReadable() else { return }
        updateCurrent { data in
            guard let index = data.bonuses?.firstIndex(where: { $0.id == id }),
                  let record = data.bonuses?.remove(at: index)
            else { return }
            data.counts[record.kind.rawValue] = max(0, data.counts[record.kind.rawValue, default: 0] - 1)
            if let historyIndex = data.history.lastIndex(of: record.kind) {
                data.history.remove(at: historyIndex)
            }
            data.lastAction = "削除 \(record.label)"
        }
    }

    private static func add(_ role: Role, to data: inout CounterData) {
        data.counts[role.rawValue, default: 0] += 1
        data.history.append(role)
        if data.history.count > historyLimit {
            data.history.removeFirst(data.history.count - historyLimit)
        }
    }

    func undo() {
        guard ensureReadable(), canUndo else { return }
        updateCurrent { data in
            guard let last = data.history.popLast() else { return }
            data.counts[last.rawValue] = max(0, data.counts[last.rawValue, default: 0] - 1)
            if last == .big || last == .reg,
               let index = data.bonuses?.lastIndex(where: { $0.kind == last }) {
                data.bonuses?.remove(at: index)
            }
            data.lastAction = "取消 \(last.label)"
        }
    }

    /// データカウンターの総回転数（打ち始め）
    func setStartTotal(_ total: Int?) {
        guard ensureReadable() else { return }
        updateCurrent { $0.startTotal = total.map { max(0, $0) } }
    }

    /// データカウンターの総回転数（現在）
    func setCurrentTotal(_ total: Int?) {
        guard ensureReadable() else { return }
        updateCurrent { $0.currentTotal = total.map { max(0, $0) } }
    }

    func setJugglerModel(_ model: JugglerModel) {
        guard ensureReadable() else { return }
        updateCurrent { $0.jugglerModel = model }
    }

    /// 選択中の機種のカウント・総回転数・ボーナスをリセットする（再生ボタンの割り当てと機種は残す）
    func resetCurrentMachine() {
        guard ensureReadable() else { return }
        let old = current
        var fresh = CounterData()
        fresh.nextTrackRole = old.nextTrackRole
        fresh.previousTrackRole = old.previousTrackRole
        fresh.jugglerModel = old.jugglerModel
        store.machines[store.selected.rawValue] = fresh
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
            bonusTotal: bonusTotal,
            sinceLastBonus: sinceLastBonus
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
        onChange?()
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
        store.schemaVersion = CounterStore.currentSchemaVersion
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
