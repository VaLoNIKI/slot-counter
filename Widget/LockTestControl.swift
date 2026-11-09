import AppIntents
import Foundation
import SwiftUI
import WidgetKit

// 診断用：ロック中に「ウィジェット拡張の中だけで動く Intent」なら解除なしで実行されるかを確かめるコントロール。
// 小役用の Intent（LiveActivityIntent）はアプリ本体を起動して実行されるが、こちらは普通の AppIntent なので
// ウィジェット拡張のプロセスで実行される。押すたびにアイコンの数字が 0→1→2… と増える（50 で止まる）。
// 確認が済んだら削除する。

enum LockTestStore {
    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "locktest.json")
    }

    static func value() -> Int {
        guard
            let data = try? Data(contentsOf: fileURL),
            let number = try? JSONDecoder().decode(Int.self, from: data)
        else { return 0 }
        return number
    }

    static func increment() {
        let next = min(value() + 1, 50)
        guard let data = try? JSONEncoder().encode(next) else { return }
        try? FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory,
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

struct LockTestIntent: AppIntent {
    static var title: LocalizedStringResource = "ロック中テスト"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        LockTestStore.increment()
        ControlCenter.shared.reloadControls(ofKind: LockTestControl.kind)
        return .result()
    }
}

struct LockTestControl: ControlWidget {
    static let kind = "com.valoniki.slotcounter.control.locktest"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { value in
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
            LockTestStore.value()
        }
    }
}
