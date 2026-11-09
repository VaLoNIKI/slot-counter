import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// ライブアクティビティ。各項目のタイルは Button(intent:) で +1 できる。
// ロック中にタイルを押すと iOS の仕様で Face ID などの解除が求められ、解除後に実行される。
// ロックしたまま入力したいときはコントロール（CounterControls.swift）を使う。

struct CounterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SlotCounterAttributes.self) { context in
            LockScreenCounterView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(context.state.machineName)
                            .font(.caption.bold())
                        if context.state.totalGames > 0 {
                            Text("\(context.state.totalGames)G")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    UndoButton(enabled: context.state.canUndo)
                }
                DynamicIslandExpandedRegion(.center) {
                    if let last = context.state.lastAction {
                        Text(last)
                            .font(.caption2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RoleButtonsRow(state: context.state, tileHeight: 52)
                }
            } compactLeading: {
                CompactItemView(item: compactItems(context.state).first)
            } compactTrailing: {
                CompactItemView(item: compactItems(context.state).dropFirst().first)
            } minimal: {
                Text("\(context.state.total)")
                    .font(.caption2.bold().monospacedDigit())
            }
        }
    }

    /// ボーナスがある機種は BIG/REG、それ以外は先頭の2項目を出す
    private func compactItems(_ state: SlotCounterAttributes.ContentState) -> [SlotCounterAttributes.ContentState.Item] {
        let bonus = state.items.filter { $0.role == .big || $0.role == .reg }
        return bonus.count == 2 ? bonus : Array(state.items.prefix(2))
    }
}

private struct CompactItemView: View {
    let item: SlotCounterAttributes.ContentState.Item?

    var body: some View {
        if let item, let role = item.role {
            HStack(spacing: 2) {
                Text(role.shortLabel).foregroundStyle(role.color)
                Text("\(item.count)").monospacedDigit()
            }
            .font(.caption2.bold())
        }
    }
}

/// ロック画面表示（高さ約135pt。上限の160ptに収める）
struct LockScreenCounterView: View {
    let state: SlotCounterAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(state.machineName)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
                if state.totalGames > 0 {
                    Text("\(state.totalGames)G")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                }
                if let bonus = state.bonusTotal {
                    Text("合算 \(Probability.text(games: state.totalGames, count: bonus))")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                UndoButton(enabled: state.canUndo)
            }
            RoleButtonsRow(state: state, tileHeight: 60)
            if let last = state.lastAction {
                Text("直前: \(last)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct RoleButtonsRow: View {
    let state: SlotCounterAttributes.ContentState
    let tileHeight: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            ForEach(state.items) { item in
                if let role = item.role {
                    RoleCountButton(role: role) {
                        RoleTile(role: role, count: item.count, totalGames: state.totalGames, height: tileHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// 小役ごとの専用 Intent（パラメータなし）で +1 するボタン
private struct RoleCountButton<Label: View>: View {
    let role: Role
    @ViewBuilder let label: () -> Label

    var body: some View {
        switch role {
        case .grape: Button(intent: GrapePlusOneIntent(), label: label)
        case .cherry: Button(intent: CherryPlusOneIntent(), label: label)
        case .bell: Button(intent: BellPlusOneIntent(), label: label)
        case .watermelon: Button(intent: WatermelonPlusOneIntent(), label: label)
        case .chance: Button(intent: ChancePlusOneIntent(), label: label)
        case .big: Button(intent: BigPlusOneIntent(), label: label)
        case .reg: Button(intent: RegPlusOneIntent(), label: label)
        }
    }
}

private struct RoleTile: View {
    let role: Role
    let count: Int
    let totalGames: Int
    let height: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            Text(role.label)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(count)")
                .font(.title2.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(Probability.text(games: totalGames, count: count))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
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

struct UndoButton: View {
    let enabled: Bool

    var body: some View {
        Button(intent: UndoLastIntent()) {
            Label("取消", systemImage: "arrow.uturn.backward")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(enabled ? 1 : 0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(enabled ? 0.22 : 0.08)))
        }
        .buttonStyle(.plain)
    }
}
