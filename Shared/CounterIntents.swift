import AppIntents

// 小役ごとの +1 Intent と取消 Intent。
// コントロール（ControlWidgetButton）、ライブアクティビティのボタン（Button(intent:)）、
// ショートカット（App Shortcuts）のすべてがこの Intent を使う。
//
// - 小役ごとに型を分けてパラメータを持たせない。パラメータがあると、実行時に iOS が値の確認を
//   必要と判断してロック解除を求めることがあるため。
// - LiveActivityIntent なので、ウィジェット拡張ではなくアプリのプロセスで実行され、
//   保存とライブアクティビティの更新をその場で行える（App Groups 不要）。
// - アプリを前面に出さない（iOS 26 以降 supportedModes = .background、iOS 18 は openAppWhenRun = false）。
// - ロック中でも実行できる（authenticationPolicy = .alwaysAllowed）。

struct GrapePlusOneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "ブドウ +1"
    static var description = IntentDescription("選択中の機種のブドウを1回カウントします。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.incrementAndSync(.grape)
        return .result()
    }
}

struct CherryPlusOneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "チェリー +1"
    static var description = IntentDescription("選択中の機種のチェリーを1回カウントします。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.incrementAndSync(.cherry)
        return .result()
    }
}

struct BellPlusOneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "ベル +1"
    static var description = IntentDescription("選択中の機種のベルを1回カウントします。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.incrementAndSync(.bell)
        return .result()
    }
}

struct WatermelonPlusOneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "スイカ +1"
    static var description = IntentDescription("選択中の機種のスイカを1回カウントします。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.incrementAndSync(.watermelon)
        return .result()
    }
}

struct ChancePlusOneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "チャンス目 +1"
    static var description = IntentDescription("選択中の機種のチャンス目を1回カウントします。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.incrementAndSync(.chance)
        return .result()
    }
}

struct BigPlusOneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "BIG +1"
    static var description = IntentDescription("選択中の機種のBIGを1回カウントします。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.incrementAndSync(.big)
        return .result()
    }
}

struct RegPlusOneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "REG +1"
    static var description = IntentDescription("選択中の機種のREGを1回カウントします。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.incrementAndSync(.reg)
        return .result()
    }
}

struct UndoShortcutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "小役 直前を取消"
    static var description = IntentDescription("選択中の機種の最後のカウントを1つ取り消します。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.undoAndSync()
        return .result()
    }
}

/// コントロールとライブアクティビティの取消ボタン用（ショートカットアプリには出さない）
struct UndoLastIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "直前を取り消す"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await CounterModel.shared.undoAndSync()
        return .result()
    }
}
