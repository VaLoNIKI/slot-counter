import Foundation

/// 1設定ぶんの公表スペック。確率は「1/x」の x を持つ
struct SettingSpec: Hashable {
    let setting: Int
    let big: Double
    let reg: Double
    let combined: Double
    let grape: Double
    /// 機械割（%）
    let payout: Double
}

/// スペック表と比べる指標
enum SpecMetric: CaseIterable {
    case big
    case reg
    case combined
    case grape

    var label: String {
        switch self {
        case .big: "BIG"
        case .reg: "REG"
        case .combined: "合算"
        case .grape: "ぶどう"
        }
    }

    func value(in spec: SettingSpec) -> Double {
        switch self {
        case .big: spec.big
        case .reg: spec.reg
        case .combined: spec.combined
        case .grape: spec.grape
        }
    }
}

/// ジャグラーの機種（現行の6号機のみ。5号機とアイムジャグラーEX(6号機)は含めない）。
/// 数値の出典：ジャグラースペック一覧表 https://smokefield.info/slot/jugglerspec.html
/// （2026-11-09 に保存したページ）
enum JugglerModel: String, Codable, CaseIterable, Identifiable {
    case myJuggler6
    case neoImJugglerEX
    case ultraMiracle
    case misterJuggler
    case girlsSS
    case gogo3
    case happyV3
    case myJuggler5
    case funky2

    static let defaultModel: JugglerModel = .myJuggler6

    var id: String { rawValue }

    var label: String {
        switch self {
        case .myJuggler6: "マイジャグラーⅥ"
        case .neoImJugglerEX: "ネオアイムジャグラーEX"
        case .ultraMiracle: "ウルトラミラクルジャグラー"
        case .misterJuggler: "ミスタージャグラー"
        case .girlsSS: "ジャグラーガールズSS"
        case .gogo3: "GOGOジャグラー3"
        case .happyV3: "ハッピージャグラーVⅢ"
        case .myJuggler5: "マイジャグラーⅤ"
        case .funky2: "ファンキージャグラー2"
        }
    }

    /// 設定1〜6のスペック（BIG, REG, 合算, 機械割, ぶどう の順で表から転記）
    var specs: [SettingSpec] {
        switch self {
        case .myJuggler6, .myJuggler5:
            Self.table([
                (273.1, 409.6, 163.8, 97.85, 5.90),
                (270.8, 385.5, 159.1, 98.88, 5.86),
                (266.4, 336.1, 148.6, 100.80, 5.82),
                (254.0, 290.0, 135.4, 103.77, 5.80),
                (240.1, 268.6, 126.8, 106.39, 5.78),
                (229.1, 229.1, 114.6, 110.53, 5.67),
            ])
        case .neoImJugglerEX:
            Self.table([
                (273.1, 439.8, 168.5, 97.83, 6.05),
                (269.7, 399.6, 161.0, 98.87, 6.05),
                (269.7, 331.0, 148.6, 100.43, 6.05),
                (259.0, 315.1, 142.2, 102.08, 6.05),
                (259.0, 255.0, 128.5, 104.29, 6.05),
                (255.0, 255.0, 127.5, 106.54, 5.79),
            ])
        case .ultraMiracle:
            Self.table([
                (267.5, 425.6, 164.3, 97.88, 5.94),
                (261.1, 402.1, 158.3, 98.99, 5.94),
                (256.0, 350.5, 147.9, 100.67, 5.94),
                (242.7, 322.8, 138.6, 102.99, 5.94),
                (233.2, 297.9, 130.8, 105.50, 5.88),
                (216.3, 277.7, 121.6, 109.14, 5.82),
            ])
        case .misterJuggler:
            Self.table([
                (268.6, 374.5, 156.4, 97.99, 6.30),
                (267.5, 354.2, 152.4, 99.01, 6.23),
                (260.1, 331.0, 145.6, 100.85, 6.16),
                (249.2, 291.3, 134.3, 103.76, 6.09),
                (240.9, 257.0, 124.4, 106.60, 6.02),
                (237.4, 237.4, 118.7, 108.42, 5.95),
            ])
        case .girlsSS:
            Self.table([
                (273.1, 381.0, 159.1, 97.83, 5.99),
                (270.8, 350.5, 152.8, 98.75, 5.99),
                (260.1, 316.6, 142.8, 100.80, 5.99),
                (250.1, 281.3, 132.4, 103.11, 5.99),
                (243.6, 270.8, 128.3, 104.94, 5.90),
                (226.0, 252.1, 119.2, 108.53, 5.84),
            ])
        case .gogo3:
            Self.table([
                (259.0, 354.2, 149.6, 98.02, 6.27),
                (258.0, 332.7, 145.3, 99.06, 6.21),
                (257.0, 306.2, 139.7, 100.35, 6.15),
                (254.0, 268.6, 130.5, 102.53, 6.08),
                (247.3, 247.3, 123.7, 104.75, 6.01),
                (234.9, 234.9, 117.4, 107.48, 5.93),
            ])
        case .happyV3:
            Self.table([
                (273.1, 397.2, 161.8, 97.60, 6.05),
                (270.8, 362.1, 154.9, 98.71, 6.02),
                (263.2, 332.7, 146.9, 100.51, 5.99),
                (254.0, 300.6, 137.7, 103.47, 5.85),
                (239.2, 273.1, 127.5, 106.48, 5.82),
                (226.0, 256.0, 120.0, 109.12, 5.79),
            ])
        case .funky2:
            Self.table([
                (266.4, 439.8, 165.9, 97.87, 5.94),
                (259.0, 407.1, 158.3, 99.41, 5.91),
                (256.0, 366.1, 150.7, 100.73, 5.89),
                (249.2, 322.8, 140.6, 102.95, 5.85),
                (240.1, 299.3, 133.2, 105.29, 5.78),
                (219.9, 262.1, 119.6, 110.05, 5.70),
            ])
        }
    }

    private static func table(
        _ rows: [(big: Double, reg: Double, combined: Double, payout: Double, grape: Double)]
    ) -> [SettingSpec] {
        rows.enumerated().map { index, row in
            SettingSpec(
                setting: index + 1,
                big: row.big,
                reg: row.reg,
                combined: row.combined,
                grape: row.grape,
                payout: row.payout
            )
        }
    }

    /// 実測の「1/x」の x に一番近い設定。同じ値の設定が複数あれば全部返す。
    /// 設定推測ではなく、表のどの行に近いかを示すだけ。
    func nearestSettings(_ metric: SpecMetric, observed: Double) -> [Int] {
        let distances = specs.map { abs(metric.value(in: $0) - observed) }
        guard let best = distances.min() else { return [] }
        return zip(specs, distances)
            .filter { $0.1 - best < 0.0001 }
            .map { $0.0.setting }
    }

    /// [4] → "設定4"、[1,2,3,4,5] → "設定1〜5"
    static func settingsLabel(_ settings: [Int]) -> String {
        guard let first = settings.first, let last = settings.last else { return "" }
        if first == last { return "設定\(first)" }
        if last - first + 1 == settings.count { return "設定\(first)〜\(last)" }
        return "設定" + settings.map(String.init).joined(separator: "・")
    }
}
