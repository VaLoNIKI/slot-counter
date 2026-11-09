import AppIntents
import SwiftUI
import WidgetKit

// 診断用コントロール。Intent と保存は Shared/LockTest.swift。確認が済んだら削除する。

struct LockTestControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: LockTest.controlKind, provider: Provider()) { value in
            ControlWidgetButton(action: LockTestIntent()) {
                Label("テスト \(value)", systemImage: "\(value).circle.fill")
            }
        }
        .displayName("ロック中テスト")
        .description("診断用。押すたびに数字が増えます。")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Int { 0 }

        func currentValue() async throws -> Int {
            LockTest.value()
        }
    }
}
