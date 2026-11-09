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
    /// 非重複チェリー（ボーナスと重ならなかったチェリー）。資料に設定別の値がない機種は nil
    var cherry: Double?
    /// 単独BIG・チェリー重複BIG・単独REG・チェリー重複REG。資料にない機種は nil
    var aloneBig: Double?
    var cherryBig: Double?
    var aloneReg: Double?
    var cherryReg: Double?
}

/// スペック表と比べる指標
enum SpecMetric: CaseIterable {
    case big
    case reg
    case combined
    case grape
    case cherry
    case aloneReg

    var label: String {
        switch self {
        case .big: "BIG"
        case .reg: "REG"
        case .combined: "合算"
        case .grape: "ぶどう"
        case .cherry: "チェリー"
        case .aloneReg: "単独REG"
        }
    }

    /// その設定の値。資料にない項目は nil
    func value(in spec: SettingSpec) -> Double? {
        switch self {
        case .big: spec.big
        case .reg: spec.reg
        case .combined: spec.combined
        case .grape: spec.grape
        case .cherry: spec.cherry
        case .aloneReg: spec.aloneReg
        }
    }
}

/// ジャグラーの機種（現行の6号機のみ。5号機とアイムジャグラーEX(6号機)は含めない）。
/// 数値の出典：ジャグラースペック一覧表 https://smokefield.info/slot/jugglerspec.html と
/// 各機種の詳細ページ https://smokefield.info/slot/jugglerspec/<機種>.html（2026-11-09 取得）
/// - チェリー（非重複）に設定別の値があるのはマイジャグラーⅥ・Ⅴ、ハッピージャグラーVⅢ。
///   ネオアイム・ガールズSS・GOGO3・ファンキー2 は全設定共通 1/35.6（設定差なし）。
///   ミスター・ウルトラミラクルは公式の設定別の値が見つからないので nil
/// - 単独/重複 BIG・REG はミスター以外の8機種に設定別の値がある
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

    /// 設定1〜6のスペック（基本の表に、チェリーと単独/重複の内訳を合わせたもの）
    var specs: [SettingSpec] {
        let cherry = cherryTable
        let breakdown = breakdownTable
        return baseSpecs.enumerated().map { index, base in
            var spec = base
            spec.cherry = cherry?[index]
            if let row = breakdown?[index] {
                spec.aloneBig = row.aloneBig
                spec.cherryBig = row.cherryBig
                spec.aloneReg = row.aloneReg
                spec.cherryReg = row.cherryReg
            }
            return spec
        }
    }

    /// 非重複チェリー（設定1〜6）
    private var cherryTable: [Double]? {
        switch self {
        case .myJuggler6, .myJuggler5: [38.1, 38.1, 36.8, 35.6, 35.6, 35.6]
        case .happyV3: [62.1, 62.2, 62.7, 63.9, 64.5, 65.4]
        case .neoImJugglerEX, .girlsSS, .gogo3, .funky2: Array(repeating: 35.6, count: 6)
        case .ultraMiracle, .misterJuggler: nil
        }
    }

    /// 単独BIG・重複BIG・単独REG・重複REG（設定1〜6）
    private var breakdownTable: [(aloneBig: Double, cherryBig: Double, aloneReg: Double, cherryReg: Double)]? {
        switch self {
        case .myJuggler6:
            [(415, 797, 651, 1104), (411, 795, 600, 1077), (402, 792, 492, 1059),
             (377, 780, 408, 999), (350, 766, 393, 851), (342, 696, 330, 752)]
        case .myJuggler5:
            [(415, 797, 651, 1104), (411, 795, 601, 1077), (402, 792, 492, 1059),
             (377, 780, 409, 999), (350, 766, 393, 851), (342, 696, 330, 752)]
        case .neoImJugglerEX:
            [(390, 910, 621, 1510), (382, 916, 553, 1437), (381, 923, 470, 1120),
             (375, 838, 460, 1002), (372, 854, 376, 795), (364, 854, 376, 795)]
        case .ultraMiracle:
            [(425, 722, 677, 1147), (423, 681, 626, 1123), (416, 665, 513, 1104),
             (388, 647, 455, 1113), (380, 603, 435, 944), (345, 579, 399, 912)]
        case .girlsSS:
            [(389, 916, 524, 1397), (383, 924, 485, 1262), (372, 867, 440, 1128),
             (353, 861, 401, 942), (340, 859, 385, 912), (315, 801, 360, 839)]
        case .gogo3:
            [(346, 1032, 472, 1417), (344, 1032, 447, 1297), (344, 1020, 418, 1147),
             (342, 985, 363, 1034), (333, 963, 331, 978), (317, 906, 317, 906)]
        case .happyV3:
            [(371, 1038, 635, 1059), (365, 1047, 562, 1018), (351, 1053, 532, 887),
             (358, 875, 474, 823), (331, 864, 432, 741), (307, 857, 427, 640)]
        case .funky2:
            [(394, 821, 631, 1452), (379, 817, 574, 1400), (374, 811, 505, 1333),
             (360, 808, 446, 1171), (343, 802, 407, 1128), (305, 792, 352, 1024)]
        case .misterJuggler:
            nil
        }
    }

    /// その項目に設定差があるか（全設定同じ値なら判別に使えない）
    func hasSettingDifference(_ metric: SpecMetric) -> Bool {
        let values = specs.compactMap { metric.value(in: $0) }
        guard values.count == specs.count, let first = values.first else { return false }
        return values.contains { $0 != first }
    }

    /// 基本の表（BIG, REG, 合算, 機械割, ぶどう の順で一覧表から転記）
    private var baseSpecs: [SettingSpec] {
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
        let pairs = specs.compactMap { spec in metric.value(in: spec).map { (spec.setting, abs($0 - observed)) } }
        guard pairs.count == specs.count, let best = pairs.map({ $0.1 }).min() else { return [] }
        return pairs.filter { $0.1 - best < 0.0001 }.map { $0.0 }
    }

    /// [4] → "設定4"、[1,2,3,4,5] → "設定1〜5"
    static func settingsLabel(_ settings: [Int]) -> String {
        guard let first = settings.first, let last = settings.last else { return "" }
        if first == last { return "設定\(first)" }
        if last - first + 1 == settings.count { return "設定\(first)〜\(last)" }
        return "設定" + settings.map(String.init).joined(separator: "・")
    }
}
