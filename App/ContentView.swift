import SwiftUI

/// 実戦画面（デザイン案 D）。
/// 上：機種・直前の操作・履歴とメニュー / 帯：G数・ボーナス合算・ぶどう合算 / 設定推測 / 補足の数字
/// 下：親指で届く大きな4つのボタンと取消。設定類はメニュー（シート）に置く。
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = CounterModel.shared
    @State private var activity = LiveActivityController()
    @State private var nowPlaying = NowPlayingCounter.shared
    /// BIG / REG を押したときに重ねて出す選択肢（nil なら非表示）
    @State private var bonusPicker: Role?
    @State private var showGames = false
    @State private var showMenu = false
    @State private var showHistory = false
    /// 押したときの振動のきっかけ
    @State private var tapCount = 0

    private var machine: Machine { model.selectedMachine }

    private var stats: PlayStats {
        PlayStats(machine: machine, data: model.current)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 10) {
                header
                summaryBand
                if machine == .juggler, let estimate = stats.settingEstimate {
                    EstimateStrip(estimate: estimate)
                }
                infoRow
                Spacer(minLength: 0)
                buttonGrid
                undoButton
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 10)

            if let kind = bonusPicker {
                BonusPickerOverlay(kind: kind) { overlap in
                    model.recordBonus(kind, overlap: overlap, totalGames: nil)
                    hideOverlays()
                    tapCount += 1
                    sync()
                } onCancel: {
                    hideOverlays()
                }
            }

            if showGames {
                GamesOverlay(model: model, onChange: sync, onClose: hideOverlays)
            }
        }
        .foregroundStyle(Theme.text)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .sheet(isPresented: $showMenu) {
            MenuView(activity: activity)
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                SessionListView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showHistory = false }
                        }
                    }
            }
        }
        .onAppear {
            activity.refresh()
            nowPlaying.restoreIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.reloadFromDisk()
                activity.refresh()
            }
        }
    }

    // MARK: - 上：機種と操作

    private var header: some View {
        HStack(alignment: .center) {
            machineMenu
            Spacer(minLength: 8)
            if FeatureAccess.isUnlocked(.sessionHistory) {
                circleButton("clock.arrow.circlepath", label: "履歴") { showHistory = true }
            }
            circleButton("line.3.horizontal", label: "メニュー") { showMenu = true }
        }
    }

    private var machineTitle: String {
        machine == .juggler ? model.jugglerModel.label : machine.label
    }

    private var machineMenu: some View {
        Menu {
            Section("ジャグラー") {
                ForEach(JugglerModel.allCases) { jugglerModel in
                    Button {
                        model.selectMachine(.juggler)
                        model.setJugglerModel(jugglerModel)
                        sync()
                    } label: {
                        if machine == .juggler && model.jugglerModel == jugglerModel {
                            Label(jugglerModel.label, systemImage: "checkmark")
                        } else {
                            Text(jugglerModel.label)
                        }
                    }
                }
            }
            Section {
                ForEach([Machine.hanahana, Machine.generic]) { other in
                    Button {
                        model.selectMachine(other)
                        sync()
                    } label: {
                        if machine == other {
                            Label(other.label, systemImage: "checkmark")
                        } else {
                            Text(other.label)
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(machineTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.subtext)
                }
                statusLine
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("機種: \(machineTitle)")
        .accessibilityHint("タップで台・機種を切り替え")
    }

    private var statusLine: some View {
        HStack(spacing: 4) {
            Text(model.current.lastAction.map { "直前 \($0)" } ?? "直前 なし")
                .foregroundStyle(Theme.subtext)
            if nowPlaying.isRunning {
                Text("・ 再生ボタン ON")
                    .foregroundStyle(Theme.ok)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    private func circleButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - 帯：G数・ボーナス合算・ぶどう合算

    private var bandItems: [(label: String, value: String)] {
        let games = stats.games
        switch machine {
        case .juggler:
            return [
                ("G数", "\(games)"),
                ("ボーナス合算", stats.probability(stats.bonusTotal)),
                ("ぶどう合算", stats.probability(stats.count(.grape))),
            ]
        case .hanahana:
            return [
                ("G数", "\(games)"),
                ("ボーナス合算", stats.probability(stats.bonusTotal)),
                ("ベル", stats.probability(stats.count(.bell))),
            ]
        case .generic:
            return [
                ("G数", "\(games)"),
                ("ベル", stats.probability(stats.count(.bell))),
                ("チェリー", stats.probability(stats.count(.cherry))),
            ]
        }
    }

    private var summaryBand: some View {
        HStack(spacing: 1) {
            ForEach(Array(bandItems.enumerated()), id: \.offset) { index, item in
                let cell = VStack(spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.subtext)
                    Text(item.value)
                        .font(Theme.figure(26))
                        .foregroundStyle(Theme.led)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.horizontal, 4)
                .background(Theme.band)

                if index == 0 {
                    // G数はタップで総回転数の入力を出す
                    Button {
                        showOverlay { showGames = true }
                    } label: {
                        cell
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("タップで総回転数を入力")
                } else {
                    cell
                }
            }
        }
        .background(Theme.line)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 補足の数字

    private var infoItems: [String] {
        var items: [String] = []
        if let since = model.sinceLastBonus {
            items.append("ハマり \(since)G")
        }
        switch machine {
        case .juggler:
            items.append("BIG \(stats.probability(stats.count(.big)))")
            items.append("REG \(stats.probability(stats.count(.reg)))")
            items.append("単独REG \(stats.probability(stats.bonusCount(.reg, .alone)))")
        case .hanahana:
            items.append("BIG \(stats.probability(stats.count(.big)))")
            items.append("REG \(stats.probability(stats.count(.reg)))")
        case .generic:
            break
        }
        return items
    }

    @ViewBuilder
    private var infoRow: some View {
        let items = infoItems
        if !items.isEmpty {
            HStack {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(Theme.softText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    // MARK: - 下：大きな4つのボタン

    private var buttonGrid: some View {
        let roles = machine.roles
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(roles.prefix(2)) { role in
                    roleButton(role, numberSize: 60, minHeight: 110, maxHeight: 168)
                }
            }
            HStack(spacing: 10) {
                ForEach(roles.dropFirst(2)) { role in
                    roleButton(role, numberSize: 44, minHeight: 88, maxHeight: 120)
                }
            }
        }
    }

    private func roleButton(_ role: Role, numberSize: CGFloat, minHeight: CGFloat, maxHeight: CGFloat) -> some View {
        Button {
            press(role)
        } label: {
            VStack(spacing: 2) {
                Text(role.label)
                    .font(.system(size: 16, weight: .bold))
                Text("\(model.count(role))")
                    .font(Theme.counter(numberSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(subtitle(for: role))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight)
            .background(role.tileColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(role.label) \(model.count(role))回")
        .accessibilityHint(isBonusWithPicker(role) ? "タップで単独・チェリー・判別不能を選ぶ" : "タップで1回カウント")
    }

    /// ボタンの3行目：小役は確率、ジャグラーの BIG/REG は単独・チェリー・不明の内訳
    private func subtitle(for role: Role) -> String {
        if machine == .juggler && (role == .big || role == .reg) {
            let alone = stats.bonusCount(role, .alone)
            let cherry = stats.bonusCount(role, .cherry)
            let unknown = stats.bonusCount(role, .unknown)
            var text = "単独\(alone) チェ\(cherry)"
            if unknown > 0 { text += " 不明\(unknown)" }
            return text
        }
        return stats.probability(model.count(role))
    }

    private func isBonusWithPicker(_ role: Role) -> Bool {
        machine == .juggler && (role == .big || role == .reg)
    }

    private func press(_ role: Role) {
        if isBonusWithPicker(role) {
            showOverlay { bonusPicker = role }
            return
        }
        if machine.hasBonus && (role == .big || role == .reg) {
            model.recordBonus(role, overlap: nil, totalGames: nil)
        } else {
            model.increment(role)
        }
        tapCount += 1
        sync()
    }

    // MARK: - 取消

    private var undoButton: some View {
        Button {
            model.undo()
            tapCount += 1
            sync()
        } label: {
            Label("取消", systemImage: "arrow.uturn.backward")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(model.canUndo ? Theme.text : Theme.subtext)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!model.canUndo)
    }

    // MARK: - Helpers

    /// 重ねて出す画面はアニメーションなしで出す
    private func showOverlay(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    private func hideOverlays() {
        showOverlay {
            bonusPicker = nil
            showGames = false
        }
    }

    private func sync() {
        Task { await model.syncLiveActivities() }
    }
}

/// 設定推測（暫定）の帯。案 A の形：左に暫定の設定と平均・4以上、右に6本の小さな棒
struct EstimateStrip: View {
    let estimate: SettingEstimate

    var body: some View {
        let best = estimate.mostLikely
        let maxProbability = estimate.probabilities.max() ?? 1
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("設定推測（暫定）")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.subtext)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("設定\(best)")
                        .font(.system(size: 17, weight: .black))
                    Text("平均\(String(format: "%.1f", estimate.average)) ・ 4以上 \(SettingEstimateRows.percent(estimate.atLeast(4)))")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(Theme.softText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(estimate.probabilities.enumerated()), id: \.offset) { index, probability in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index + 1 == best ? Theme.led : Theme.barMuted)
                            .frame(width: 10, height: 4 + 26 * probability / max(maxProbability, 0.0001))
                        Text("\(index + 1)")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.subtext)
                    }
                }
            }
            .frame(height: 44, alignment: .bottom)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
