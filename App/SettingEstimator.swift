import Foundation

/// 設定推測の結果（設定1〜6それぞれの確率）
struct SettingEstimate {
    /// index 0 = 設定1
    let probabilities: [Double]
    /// 計算に使った項目（"BIG", "REG", "単独/重複", "ぶどう", "チェリー"）
    let usedMetrics: [String]

    var mostLikely: Int {
        (probabilities.indices.max { probabilities[$0] < probabilities[$1] } ?? 0) + 1
    }

    /// 設定の平均（期待値）
    var average: Double {
        probabilities.enumerated().reduce(0) { $0 + Double($1.offset + 1) * $1.element }
    }

    /// 設定 n 以上である確率
    func atLeast(_ setting: Int) -> Double {
        probabilities.enumerated()
            .filter { $0.offset + 1 >= setting }
            .reduce(0) { $0 + $1.element }
    }
}

/// 推測に使う回数
struct EstimateInput {
    var games: Int
    var big: Int
    var reg: Int
    /// 重複を区別して記録したボーナス（不明は含めない）
    var aloneBig: Int
    var cherryBig: Int
    var aloneReg: Int
    var cherryReg: Int
    var grape: Int
    /// 小役ボタンで数えたチェリー（ボーナスと重なったものは BIG/REG 側で記録するので、非重複チェリーに当たる）
    var cherry: Int
}

/// スペック表の確率から、今の回数がどの設定で起こりやすいかを計算する（ベイズ推定の簡易版）。
///
/// - 1G ごとに「BIG」「REG」「ぶどう」「チェリー」「それ以外」のどれかが起きるとみなした多項分布の尤度を使う
/// - 単独/重複の内訳が分かるボーナスは、資料の単独BIG・重複BIG・単独REG・重複REG の確率を使う。
///   判別不能のボーナスは BIG / REG 全体の確率を使う
/// - 事前確率は設定1〜6すべて同じ（ホールの設定配分は考えない）
/// - ぶどう・チェリーは数えている場合（1回以上）だけ使う。数えていないのに0回として扱うと大きく狂うため
/// - チェリーは資料に設定差がある機種（マイジャグラーⅥ・Ⅴ、ハッピーVⅢ）だけ使う
enum SettingEstimator {
    static func estimate(model: JugglerModel, input: EstimateInput) -> SettingEstimate? {
        guard input.games > 0 else { return nil }
        let useGrape = input.grape > 0
        let useCherry = input.cherry > 0 && model.hasSettingDifference(.cherry)
        let useBreakdown = model.specs.allSatisfy { $0.aloneBig != nil }
            && (input.aloneBig + input.cherryBig + input.aloneReg + input.cherryReg) > 0
        let unknownBig = max(0, input.big - input.aloneBig - input.cherryBig)
        let unknownReg = max(0, input.reg - input.aloneReg - input.cherryReg)

        var used = ["BIG", "REG"]
        if useBreakdown { used.append("単独/重複") }
        if useGrape { used.append("ぶどう") }
        if useCherry { used.append("チェリー") }

        let logLikelihoods = model.specs.map { spec -> Double in
            let pBig = 1 / spec.big
            let pReg = 1 / spec.reg
            var value = 0.0

            if useBreakdown,
               let aloneBig = spec.aloneBig, let cherryBig = spec.cherryBig,
               let aloneReg = spec.aloneReg, let cherryReg = spec.cherryReg {
                value += Double(input.aloneBig) * log(1 / aloneBig)
                value += Double(input.cherryBig) * log(1 / cherryBig)
                value += Double(unknownBig) * log(1 / aloneBig + 1 / cherryBig)
                value += Double(input.aloneReg) * log(1 / aloneReg)
                value += Double(input.cherryReg) * log(1 / cherryReg)
                value += Double(unknownReg) * log(1 / aloneReg + 1 / cherryReg)
            } else {
                value += Double(input.big) * log(pBig) + Double(input.reg) * log(pReg)
            }

            var pCounted = pBig + pReg
            var counted = input.big + input.reg
            if useGrape {
                let pGrape = 1 / spec.grape
                value += Double(input.grape) * log(pGrape)
                pCounted += pGrape
                counted += input.grape
            }
            if useCherry, let cherry = spec.cherry {
                let pCherry = 1 / cherry
                value += Double(input.cherry) * log(pCherry)
                pCounted += pCherry
                counted += input.cherry
            }

            let rest = max(0, input.games - counted)
            value += Double(rest) * log(max(1e-12, 1 - pCounted))
            return value
        }

        // 桁あふれを防ぐため最大値を引いてから指数に戻す
        guard let maxLog = logLikelihoods.max() else { return nil }
        let weights = logLikelihoods.map { exp($0 - maxLog) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        return SettingEstimate(probabilities: weights.map { $0 / total }, usedMetrics: used)
    }
}

extension PlayStats {
    /// ジャグラーの設定推測（暫定）
    var settingEstimate: SettingEstimate? {
        guard FeatureAccess.isUnlocked(.settingEstimate), let model = jugglerModel else { return nil }
        return SettingEstimator.estimate(model: model, input: EstimateInput(
            games: games,
            big: count(.big),
            reg: count(.reg),
            aloneBig: bonusCount(.big, .alone),
            cherryBig: bonusCount(.big, .cherry),
            aloneReg: bonusCount(.reg, .alone),
            cherryReg: bonusCount(.reg, .cherry),
            grape: count(.grape),
            cherry: count(.cherry)
        ))
    }
}
