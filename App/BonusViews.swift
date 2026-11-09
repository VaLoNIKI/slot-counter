import SwiftUI

/// ボーナスを記録するときに開くシート（当選時の総回転数を入れる）
struct BonusEntry: Identifiable {
    let id = UUID()
    let kind: Role
    let overlap: BonusOverlap?

    var title: String {
        if let overlap { return "\(overlap.label)\(kind.label)" }
        return kind.label
    }
}

struct BonusEntrySheet: View {
    let entry: BonusEntry
    let initialTotal: Int?
    let onRecord: (Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var totalText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例: 2345", text: $totalText)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .font(.title2.monospacedDigit())
                } header: {
                    Text("当選時の総回転数（データカウンター）")
                } footer: {
                    Text("空欄でも記録できます。入れると、ボーナス間のG数とハマりが出ます。")
                }
                Section {
                    Button {
                        onRecord(Int(totalText.filter(\.isNumber)))
                        dismiss()
                    } label: {
                        Text("\(entry.title)を記録")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(entry.kind.color)
                }
            }
            .navigationTitle(entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .onAppear {
            totalText = initialTotal.map(String.init) ?? ""
            focused = true
        }
        .presentationDetents([.medium])
    }
}

/// 記録済みのボーナスを直すシート
struct BonusEditSheet: View {
    let record: BonusRecord
    let showsOverlap: Bool
    let onSave: (BonusOverlap?, Int?) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var overlap: BonusOverlap = .unknown
    @State private var totalText = ""

    var body: some View {
        NavigationStack {
            Form {
                if showsOverlap {
                    Section("重複") {
                        Picker("重複", selection: $overlap) {
                            ForEach(BonusOverlap.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section("当選時の総回転数") {
                    TextField("空欄 = 不明", text: $totalText)
                        .keyboardType(.numberPad)
                        .font(.title3.monospacedDigit())
                }
                Section {
                    Button("このボーナスを削除", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("\(record.kind.label)を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(showsOverlap ? overlap : record.overlap, Int(totalText.filter(\.isNumber)))
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            overlap = record.overlap ?? .unknown
            totalText = record.totalGames.map(String.init) ?? ""
        }
        .presentationDetents([.medium])
    }
}

/// ボーナスの集計行（実戦中の画面と履歴の詳細で共通）
struct BonusSummaryRows: View {
    let stats: PlayStats

    var body: some View {
        StatRow(label: "BIG", color: Role.big.color, count: stats.count(.big),
                probability: stats.probability(stats.count(.big)),
                nearest: stats.nearest(.big, count: stats.count(.big)))
        StatRow(label: "REG", color: Role.reg.color, count: stats.count(.reg),
                probability: stats.probability(stats.count(.reg)),
                nearest: stats.nearest(.reg, count: stats.count(.reg)))
        StatRow(label: "合算", color: .orange, count: stats.bonusTotal,
                probability: stats.probability(stats.bonusTotal),
                nearest: stats.nearest(.combined, count: stats.bonusTotal))
        if stats.machine == .juggler {
            let aloneReg = stats.bonusCount(.reg, .alone)
            let cherryReg = stats.bonusCount(.reg, .cherry)
            let aloneBig = stats.bonusCount(.big, .alone)
            let cherryBig = stats.bonusCount(.big, .cherry)
            StatRow(label: "単独REG", color: Role.reg.color, count: aloneReg,
                    probability: stats.probability(aloneReg), nearest: nil)
            StatRow(label: "チェリーREG", color: Role.reg.color, count: cherryReg,
                    probability: stats.probability(cherryReg), nearest: nil)
            StatRow(label: "単独BIG", color: Role.big.color, count: aloneBig,
                    probability: stats.probability(aloneBig), nearest: nil)
            StatRow(label: "チェリーBIG", color: Role.big.color, count: cherryBig,
                    probability: stats.probability(cherryBig), nearest: nil)
        }
    }
}

/// 「名前 回数 確率（近い設定）」の1行
struct StatRow: View {
    let label: String
    let color: Color
    let count: Int
    let probability: String
    let nearest: String?

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 6, height: 28)
            Text(label)
            Spacer()
            Text("\(count)回")
                .font(.title3.bold().monospacedDigit())
            VStack(alignment: .trailing, spacing: 0) {
                Text(probability)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let nearest {
                    Text(nearest + "付近")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 80, alignment: .trailing)
        }
    }
}

/// ボーナス履歴の1行
struct BonusHistoryRow: View {
    let number: Int
    let record: BonusRecord
    let gamesBetween: Int?

    var body: some View {
        HStack {
            Text("\(number)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            Text(record.label)
                .bold()
                .foregroundStyle(record.kind.color)
            Spacer()
            if let gamesBetween {
                Text("\(gamesBetween)G")
                    .font(.body.monospacedDigit())
            }
            Text(record.totalGames.map { "総\($0)" } ?? "総 -")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
    }
}
