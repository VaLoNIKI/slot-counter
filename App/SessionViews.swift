import SwiftUI

/// 「実戦を保存して新しく始める」シート
struct SessionSaveSheet: View {
    let stats: PlayStats
    let initialStoreName: String
    let onSave: (_ storeName: String, _ machineNumber: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var storeName = ""
    @State private var machineNumber = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("店名（空欄でも可）", text: $storeName)
                    TextField("台番（空欄でも可）", text: $machineNumber)
                        .keyboardType(.numbersAndPunctuation)
                }
                Section("保存する内容") {
                    LabeledContent("機種", value: stats.jugglerModel?.label ?? stats.machine.label)
                    LabeledContent("G数", value: "\(stats.games)G")
                    if stats.machine.hasBonus {
                        LabeledContent("BIG / REG", value: "\(stats.count(.big)) / \(stats.count(.reg))")
                        LabeledContent("合算", value: stats.probability(stats.bonusTotal))
                    }
                }
                Section {
                    Button {
                        onSave(storeName.trimmingCharacters(in: .whitespaces),
                               machineNumber.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    } label: {
                        Text("保存して新しく始める")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                } footer: {
                    Text("保存すると、この機種のカウント・総回転数・ボーナス履歴は0に戻ります。保存した実戦は「履歴」から見られます。")
                }
            }
            .navigationTitle("実戦を保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .onAppear { storeName = initialStoreName }
    }
}

/// 実戦の履歴の一覧
struct SessionListView: View {
    @State private var archive = SessionArchive.shared

    var body: some View {
        List {
            if archive.sessions.isEmpty {
                Text("まだ保存した実戦はありません。実戦画面の「実戦を保存して新しく始める」で保存できます。")
                    .foregroundStyle(.secondary)
            }
            ForEach(archive.sessions) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    SessionRow(session: session)
                }
            }
            .onDelete { offsets in
                archive.delete(offsets.map { archive.sessions[$0].id })
            }
        }
        .navigationTitle("履歴")
    }
}

private struct SessionRow: View {
    let session: SessionRecord

    var body: some View {
        let stats = session.stats
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.savedAt, format: .dateTime.month().day().weekday())
                    .bold()
                Text([session.storeName, session.machineNumber.isEmpty ? "" : "\(session.machineNumber)番台"]
                    .filter { !$0.isEmpty }.joined(separator: " "))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(session.machineTitle)
                .font(.subheadline)
            HStack(spacing: 12) {
                Text("\(stats.games)G")
                if session.machine.hasBonus {
                    Text("B\(stats.count(.big)) R\(stats.count(.reg))")
                    Text("合算 \(stats.probability(stats.bonusTotal))")
                }
                if session.machine == .juggler {
                    Text("ぶどう \(stats.probability(stats.count(.grape)))")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}

/// 保存した実戦の詳細
struct SessionDetailView: View {
    let session: SessionRecord

    var body: some View {
        let stats = session.stats
        Form {
            Section {
                LabeledContent("日時") {
                    Text(session.savedAt, format: .dateTime.year().month().day().hour().minute())
                }
                if !session.storeName.isEmpty {
                    LabeledContent("店", value: session.storeName)
                }
                if !session.machineNumber.isEmpty {
                    LabeledContent("台番", value: session.machineNumber)
                }
                LabeledContent("機種", value: session.machineTitle)
                LabeledContent("G数", value: "\(stats.games)G")
                if let start = session.data.startTotal, let end = session.data.currentTotal {
                    LabeledContent("総回転数", value: "\(start) → \(end)")
                }
            }
            Section("小役") {
                ForEach(session.machine.roles.filter { $0 != .big && $0 != .reg }) { role in
                    StatRow(label: role.label, color: role.color, count: stats.count(role),
                            probability: stats.probability(stats.count(role)),
                            nearest: role == .grape ? stats.nearest(.grape, count: stats.count(role)) : nil)
                }
            }
            if session.machine.hasBonus {
                Section("ボーナス") {
                    BonusSummaryRows(stats: stats)
                }
                if !stats.bonuses.isEmpty {
                    let between = stats.gamesBetweenBonuses
                    Section("ボーナス履歴") {
                        ForEach(Array(stats.bonuses.enumerated()), id: \.element.id) { index, record in
                            BonusHistoryRow(number: index + 1, record: record, gamesBetween: between[record.id])
                        }
                    }
                }
            }
            if let model = stats.jugglerModel {
                Section {
                    NavigationLink("スペック表（\(model.label)）") {
                        SpecTableView(model: model, stats: stats)
                    }
                }
            }
        }
        .navigationTitle(session.machineTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// ジャグラーのスペック表と、今の実測値
struct SpecTableView: View {
    let model: JugglerModel
    let stats: PlayStats?

    var body: some View {
        ScrollView {
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("設定").gridColumnAlignment(.leading)
                    Text("BIG")
                    Text("REG")
                    Text("合算")
                    Text("ぶどう")
                    Text("機械割")
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                Divider()
                ForEach(model.specs, id: \.setting) { spec in
                    GridRow {
                        Text("\(spec.setting)").bold().gridColumnAlignment(.leading)
                        Text(Self.format(spec.big))
                        Text(Self.format(spec.reg))
                        Text(Self.format(spec.combined))
                        Text(String(format: "%.2f", spec.grape))
                        Text(String(format: "%.1f%%", spec.payout))
                    }
                    .font(.callout.monospacedDigit())
                }
                if let stats, stats.games > 0 {
                    Divider()
                    GridRow {
                        Text("実測").bold().foregroundStyle(.tint).gridColumnAlignment(.leading)
                        Text(Self.observed(stats, stats.count(.big)))
                        Text(Self.observed(stats, stats.count(.reg)))
                        Text(Self.observed(stats, stats.bonusTotal))
                        Text(Self.observed(stats, stats.count(.grape), decimals: 2))
                        Text("")
                    }
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.tint)
                }
            }
            .padding()
            Text("数値は 1/x の x。実測は今のG数から計算した値で、G数が少ないうちは大きくぶれます。\n出典：ジャグラースペック一覧表（smokefield.info）")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle(model.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func observed(_ stats: PlayStats, _ count: Int, decimals: Int = 1) -> String {
        guard count > 0 else { return "-" }
        return String(format: "%.\(decimals)f", Double(stats.games) / Double(count))
    }
}
