import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = CounterModel.shared
    @State private var activity = LiveActivityController()
    @State private var gamesText = ""
    @State private var showResetConfirm = false
    @FocusState private var gamesFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                liveActivitySection
                gamesSection
                countsSection
                actionsSection
            }
            .navigationTitle("小役カウンター")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { gamesFocused = false }
                }
            }
            .confirmationDialog("カウントと総G数をリセットしますか？", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("リセット", role: .destructive) {
                    model.reset()
                    gamesText = ""
                    sync()
                }
            }
        }
        .onAppear {
            gamesText = model.totalGames > 0 ? String(model.totalGames) : ""
            activity.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.reloadFromDisk()
                if !gamesFocused {
                    gamesText = model.totalGames > 0 ? String(model.totalGames) : ""
                }
                activity.refresh()
            }
        }
    }

    // MARK: - Sections

    private var liveActivitySection: some View {
        Section {
            HStack {
                Circle()
                    .fill(activity.isRunning ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(activity.isRunning ? "ロック画面に表示中" : "停止中")
                Spacer()
            }
            HStack(spacing: 12) {
                Button {
                    Task { await activity.start(with: model) }
                } label: {
                    Text(activity.isRunning ? "再開始" : "開始")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    Task { await activity.stop() }
                } label: {
                    Text("停止")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!activity.isRunning)
            }
            if let message = activity.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("ライブアクティビティ")
        } footer: {
            Text("ロック画面の表示は確認用です。カウントはコントロール（コントロールセンター／ロック画面の左右ボタン／アクションボタン）から入力します。表示は最長8時間で終了しますが、カウントは保存されているので「再開始」で続きから表示できます。")
        }
    }

    private var gamesSection: some View {
        Section("総G数") {
            HStack {
                TextField("例: 3000", text: $gamesText)
                    .keyboardType(.numberPad)
                    .focused($gamesFocused)
                    .font(.title3.monospacedDigit())
                Text("G")
                    .foregroundStyle(.secondary)
            }
            .onChange(of: gamesText) { _, newValue in
                let digits = newValue.filter(\.isNumber)
                if digits != newValue {
                    gamesText = digits
                    return
                }
                let games = Int(digits) ?? 0
                if games != model.totalGames {
                    model.setTotalGames(games)
                    sync()
                }
            }
        }
    }

    private var countsSection: some View {
        Section("小役（タップで+1）") {
            ForEach(Role.allCases) { role in
                Button {
                    model.increment(role)
                    sync()
                } label: {
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(role.color)
                            .frame(width: 6, height: 28)
                        Text(role.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(model.count(role))回")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.primary)
                        Text(Probability.text(games: model.totalGames, count: model.count(role)))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 72, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                model.undo()
                sync()
            } label: {
                Label("直前を取り消す", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("リセット", systemImage: "trash")
            }
        }
    }

    private func sync() {
        Task { await model.syncLiveActivities() }
    }
}
