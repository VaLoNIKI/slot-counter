import AppIntents

// ショートカットアプリ用の Intent（アプリ本体のターゲットだけに入れる）。
// 小役ごとに別の Intent にしているのは、App Shortcuts に「ブドウ +1」などを
// パラメータなしで確実に登録するため。
// どれも LiveActivityIntent なのでアプリのプロセスで実行され、ライブアクティビティも即更新される。
// アプリを前面に出さない（iOS 26 以降 supportedModes = .background、iOS 18 は openAppWhenRun = false）、
// ロック中でも実行できる（authenticationPolicy = .alwaysAllowed）。

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

/// ショートカットアプリ（と Siri / Spotlight）に自動で出る App Shortcuts。上限は10個。
struct SlotCounterShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GrapePlusOneIntent(),
            phrases: ["\(.applicationName)でブドウ", "\(.applicationName)でブドウを数える"],
            shortTitle: "ブドウ +1",
            systemImageName: "circle.hexagongrid.fill"
        )
        AppShortcut(
            intent: CherryPlusOneIntent(),
            phrases: ["\(.applicationName)でチェリー", "\(.applicationName)でチェリーを数える"],
            shortTitle: "チェリー +1",
            systemImageName: "circle.grid.2x1.fill"
        )
        AppShortcut(
            intent: BellPlusOneIntent(),
            phrases: ["\(.applicationName)でベル", "\(.applicationName)でベルを数える"],
            shortTitle: "ベル +1",
            systemImageName: "bell.fill"
        )
        AppShortcut(
            intent: WatermelonPlusOneIntent(),
            phrases: ["\(.applicationName)でスイカ", "\(.applicationName)でスイカを数える"],
            shortTitle: "スイカ +1",
            systemImageName: "triangle.fill"
        )
        AppShortcut(
            intent: ChancePlusOneIntent(),
            phrases: ["\(.applicationName)でチャンス目", "\(.applicationName)でチャンス目を数える"],
            shortTitle: "チャンス目 +1",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: BigPlusOneIntent(),
            phrases: ["\(.applicationName)でビッグ", "\(.applicationName)でBIGを数える"],
            shortTitle: "BIG +1",
            systemImageName: "7.circle.fill"
        )
        AppShortcut(
            intent: RegPlusOneIntent(),
            phrases: ["\(.applicationName)でレギュラー", "\(.applicationName)でREGを数える"],
            shortTitle: "REG +1",
            systemImageName: "r.circle.fill"
        )
        AppShortcut(
            intent: UndoShortcutIntent(),
            phrases: ["\(.applicationName)で取り消し", "\(.applicationName)の直前を取り消す"],
            shortTitle: "直前を取消",
            systemImageName: "arrow.uturn.backward"
        )
    }
}
