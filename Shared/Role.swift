import SwiftUI

/// 数える項目（小役・ボーナス）
enum Role: String, CaseIterable, Codable, Hashable, Identifiable {
    case bell
    case cherry
    case watermelon
    case chance
    case grape
    case big
    case reg

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bell: "ベル"
        case .cherry: "チェリー"
        case .watermelon: "スイカ"
        case .chance: "チャンス目"
        case .grape: "ブドウ"
        case .big: "BIG"
        case .reg: "REG"
        }
    }

    /// Dynamic Island など狭い場所用
    var shortLabel: String {
        switch self {
        case .bell: "ベ"
        case .cherry: "チ"
        case .watermelon: "ス"
        case .chance: "目"
        case .grape: "ブ"
        case .big: "B"
        case .reg: "R"
        }
    }

    /// コントロール（コントロールセンター等）のアイコン
    var symbolName: String {
        switch self {
        case .bell: "bell.fill"
        case .cherry: "circle.grid.2x1.fill"
        case .watermelon: "triangle.fill"
        case .chance: "sparkles"
        case .grape: "circle.hexagongrid.fill"
        case .big: "7.circle.fill"
        case .reg: "r.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .bell: .yellow
        case .cherry: .pink
        case .watermelon: .green
        case .chance: .orange
        case .grape: .purple
        case .big: .red
        case .reg: .blue
        }
    }
}

/// 機種プリセット
enum Machine: String, CaseIterable, Codable, Hashable, Identifiable {
    case generic
    case juggler
    case hanahana

    var id: String { rawValue }

    var label: String {
        switch self {
        case .generic: "汎用"
        case .juggler: "ジャグラー"
        case .hanahana: "ハナハナ"
        }
    }

    /// 表示・カウントする項目（表示順）
    var roles: [Role] {
        switch self {
        case .generic: [.bell, .cherry, .watermelon, .chance]
        case .juggler: [.grape, .cherry, .big, .reg]
        case .hanahana: [.bell, .watermelon, .big, .reg]
        }
    }

    /// ロック画面の再生ボタン（次の曲／前の曲）に最初に割り当てる項目
    var defaultNextTrackRole: Role {
        switch self {
        case .generic: .bell
        case .juggler: .grape
        case .hanahana: .bell
        }
    }

    var defaultPreviousTrackRole: Role {
        switch self {
        case .generic: .cherry
        case .juggler: .cherry
        case .hanahana: .watermelon
        }
    }

    /// BIG と REG があり、ボーナス合算を出す機種か
    var hasBonus: Bool {
        roles.contains(.big) && roles.contains(.reg)
    }
}

enum Probability {
    /// 総G数と回数から "1/xx.x" 形式の文字列を作る
    static func text(games: Int, count: Int) -> String {
        guard games > 0, count > 0 else { return "1/--" }
        let value = Double(games) / Double(count)
        if value >= 100 { return String(format: "1/%.0f", value) }
        if value >= 10 { return String(format: "1/%.1f", value) }
        // ぶどうなど 1/10 未満は小数2桁（1/5.85 と 1/5.90 の差が設定差になるため）
        return String(format: "1/%.2f", value)
    }
}
