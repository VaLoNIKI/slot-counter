import AppIntents
import Foundation
import WidgetKit

// 診断用：ロック中に「ウィジェット拡張の中で動く Intent」なら解除なしで実行されるかを確かめる。
//
// 小役用の Intent は LiveActivityIntent なのでアプリ本体を起動して実行されるが、
// こちらは普通の AppIntent なので、コントロールから押すとウィジェット拡張のプロセスで実行される。
// Apple のドキュメントどおり、普通の AppIntent はアプリ本体とウィジェット拡張の両方のターゲットに入れる
// （そのため Shared に置く）。
// 押すたびにコントロールのアイコンの数字が 0→1→2… と増える（50 で止まる）。確認が済んだら削除する。

enum LockTest {
    static let controlKind = "com.valoniki.slotcounter.control.locktest"

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

    func perform() async throws -> some IntentResult {
        LockTest.increment()
        ControlCenter.shared.reloadControls(ofKind: LockTest.controlKind)
        return .result()
    }
}
