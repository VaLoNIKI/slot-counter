import AppIntents

// コントロール（ControlWidgetButton）とライブアクティビティのボタン（Button(intent:)）から呼ばれる Intent。
// LiveActivityIntent に準拠させているので、ウィジェット拡張ではなくアプリのプロセスで実行され、
// 保存とライブアクティビティの更新をその場で行える。
// アプリを前面に出さないよう、iOS 26 以降は supportedModes = .background、
// それより前は openAppWhenRun = false を指定する。

/// 選択中の機種の項目を +1 する
struct CountRoleIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "小役をカウント"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "小役")
    var roleID: String

    init() {}

    init(role: Role) {
        roleID = role.rawValue
    }

    func perform() async throws -> some IntentResult {
        guard let role = Role(rawValue: roleID) else { return .result() }
        let model = await CounterModel.shared
        await model.increment(role)
        await model.syncLiveActivities()
        return .result()
    }
}

/// 選択中の機種の直前のカウントを取り消す
struct UndoLastIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "直前を取り消す"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    init() {}

    func perform() async throws -> some IntentResult {
        let model = await CounterModel.shared
        await model.undo()
        await model.syncLiveActivities()
        return .result()
    }
}
