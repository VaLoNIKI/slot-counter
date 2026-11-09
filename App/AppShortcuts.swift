import AppIntents

// ショートカットアプリ（と Siri / Spotlight）に自動で出る App Shortcuts。
// Intent 本体は Shared/CounterIntents.swift。
// AppShortcutsProvider はアプリ本体のターゲットにだけ置く。

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
