import AppIntents
import SwiftUI
import WidgetKit

// iOS 18 のコントロール。コントロールセンター、ロック画面の左右ボタン、アクションボタンに置ける。
// 押すと LiveActivityIntent がアプリのプロセスで実行される。

enum CounterControlKind {
    static let prefix = "com.valoniki.slotcounter.control."
}

private func roleControl(_ role: Role) -> some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: CounterControlKind.prefix + role.rawValue) {
        ControlWidgetButton(action: CountRoleIntent(role: role)) {
            Label("\(role.label) +1", systemImage: role.symbolName)
        }
        .tint(role.color)
    }
    .displayName(LocalizedStringResource(stringLiteral: "\(role.label) +1"))
    .description(LocalizedStringResource(stringLiteral: "\(role.label)を1回カウントします"))
}

struct BellControl: ControlWidget {
    var body: some ControlWidgetConfiguration { roleControl(.bell) }
}

struct CherryControl: ControlWidget {
    var body: some ControlWidgetConfiguration { roleControl(.cherry) }
}

struct WatermelonControl: ControlWidget {
    var body: some ControlWidgetConfiguration { roleControl(.watermelon) }
}

struct ChanceControl: ControlWidget {
    var body: some ControlWidgetConfiguration { roleControl(.chance) }
}

struct UndoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: CounterControlKind.prefix + "undo") {
            ControlWidgetButton(action: UndoLastIntent()) {
                Label("直前を取消", systemImage: "arrow.uturn.backward")
            }
        }
        .displayName("小役 直前を取消")
        .description("最後のカウントを1つ取り消します")
    }
}
