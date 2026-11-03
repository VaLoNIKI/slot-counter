import SwiftUI

/// 数える小役
enum Role: String, CaseIterable, Codable, Hashable, Identifiable {
    case bell
    case cherry
    case watermelon
    case chance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bell: "ベル"
        case .cherry: "チェリー"
        case .watermelon: "スイカ"
        case .chance: "チャンス目"
        }
    }

    /// Dynamic Island など狭い場所用
    var shortLabel: String {
        switch self {
        case .bell: "ベ"
        case .cherry: "チ"
        case .watermelon: "ス"
        case .chance: "目"
        }
    }

    /// コントロール（コントロールセンター等）のアイコン
    var symbolName: String {
        switch self {
        case .bell: "bell.fill"
        case .cherry: "circle.grid.2x1.fill"
        case .watermelon: "triangle.fill"
        case .chance: "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .bell: .yellow
        case .cherry: .red
        case .watermelon: .green
        case .chance: .purple
        }
    }
}

enum Probability {
    /// 総G数と回数から "1/xx.x" 形式の文字列を作る
    static func text(games: Int, count: Int) -> String {
        guard games > 0, count > 0 else { return "1/--" }
        let value = Double(games) / Double(count)
        return value >= 100
            ? String(format: "1/%.0f", value)
            : String(format: "1/%.1f", value)
    }
}
