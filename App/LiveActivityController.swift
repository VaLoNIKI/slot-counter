import ActivityKit
import Foundation
import Observation

/// ライブアクティビティの開始・停止（アプリ側のみ）
@MainActor
@Observable
final class LiveActivityController {
    private(set) var isRunning = false
    var errorMessage: String?

    func refresh() {
        isRunning = Activity<SlotCounterAttributes>.activities.contains {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    /// 既存のアクティビティを終了してから新しく開始する。
    /// カウントは CounterModel から引き継ぐので、8時間制限が近づいたら押し直せばよい。
    func start(with model: CounterModel) async {
        await endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorMessage = "ライブアクティビティがオフです。設定 > 小役カウンター でオンにしてください。"
            refresh()
            return
        }
        do {
            _ = try Activity.request(
                attributes: SlotCounterAttributes(),
                content: ActivityContent(state: model.contentState, staleDate: nil),
                pushType: nil
            )
            errorMessage = nil
        } catch {
            errorMessage = "開始できませんでした: \(error.localizedDescription)"
        }
        refresh()
    }

    func stop() async {
        await endAll()
        refresh()
    }

    private func endAll() async {
        for activity in Activity<SlotCounterAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
