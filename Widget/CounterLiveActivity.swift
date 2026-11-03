import ActivityKit
import SwiftUI
import WidgetKit

// ライブアクティビティは表示専用。入力はコントロール（CounterControls.swift）で行う。
// （ライブアクティビティ内のボタンはロック中は動作しないため置かない）

struct CounterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SlotCounterAttributes.self) { context in
            LockScreenCounterView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.totalGames > 0 ? "\(context.state.totalGames)G" : "小役")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let last = context.state.lastAction {
                        Text(last)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RoleTilesRow(state: context.state)
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Text(Role.bell.shortLabel).foregroundStyle(Role.bell.color)
                    Text("\(context.state.count(.bell))").monospacedDigit()
                }
                .font(.caption2.bold())
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text(Role.cherry.shortLabel).foregroundStyle(Role.cherry.color)
                    Text("\(context.state.count(.cherry))").monospacedDigit()
                }
                .font(.caption2.bold())
            } minimal: {
                Text("\(context.state.total)")
                    .font(.caption2.bold().monospacedDigit())
            }
        }
    }
}

/// ロック画面表示（高さ約120pt。上限の160ptに収める）
struct LockScreenCounterView: View {
    let state: SlotCounterAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("小役カウンター")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                if state.totalGames > 0 {
                    Text("\(state.totalGames)G")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
                if let last = state.lastAction {
                    Text("直前: \(last)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.18)))
                }
            }
            RoleTilesRow(state: state)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct RoleTilesRow: View {
    let state: SlotCounterAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Role.allCases) { role in
                VStack(spacing: 1) {
                    Text(role.label)
                        .font(.caption2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(state.count(role))")
                        .font(.title2.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(Probability.text(games: state.totalGames, count: state.count(role)))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(role.color.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(role.color.opacity(0.8), lineWidth: 1)
                )
            }
        }
    }
}
