import Foundation

/// 設定推測の結果（設定1〜6それぞれの確率）
struct SettingEstimate {
    /// index 0 = 設定1
    let probabilities: [Double]
    /// 計算に使った項目（"BIG", "REG", "ぶどう"）
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

/// スペック表の確率から、今の回数がどの設定で起こりやすいかを計算する（ベイズ推定の簡易版）。
///
/// - 1G ごとに「BIG」「REG」「ぶどう」「それ以外」のどれかが起きるとみなした多項分布の尤度を使う
/// - 事前確率は設定1〜6すべて同じ（ホールの設定配分は考えない）
/// - ぶどうは数えている場合（1回以上）だけ使う。数えていないのに0回として扱うと大きく狂うため
/// - チェリーや単独/重複REGは、スペック表に設定別の値がないので使わない
enum SettingEstimator {
    static func estimate(model: JugglerModel, games: Int, big: Int, reg: Int, grape: Int) -> SettingEstimate? {
        guard games > 0 else { return nil }
        let useGrape = grape > 0
        var used = ["BIG", "REG"]
        if useGrape { used.append("ぶどう") }

        let logLikelihoods = model.specs.map { spec -> Double in
            let pBig = 1 / spec.big
            let pReg = 1 / spec.reg
            let pGrape = useGrape ? 1 / spec.grape : 0
            let counted = big + reg + (useGrape ? grape : 0)
            let rest = max(0, games - counted)
            let pRest = max(1e-12, 1 - pBig - pReg - pGrape)
            var value = Double(big) * log(pBig) + Double(reg) * log(pReg) + Double(rest) * log(pRest)
            if useGrape {
                value += Double(grape) * log(pGrape)
            }
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
        return SettingEstimator.estimate(
            model: model,
            games: games,
            big: count(.big),
            reg: count(.reg),
            grape: count(.grape)
        )
    }
}
