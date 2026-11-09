import SwiftUI

/// BIG / REG を押したときに、その場に重ねて出す選択肢（アニメーションなし）。
/// 単独・チェリー重複・判別不能から選ぶ。
struct BonusPickerOverlay: View {
    let kind: Role
    let onPick: (BonusOverlap) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 10) {
                Text(kind.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.softText)
                choice("単独\(kind.label)", .alone, color: kind.tileColor)
                choice("チェリー\(kind.label)", .cherry, color: kind.tileColor)
                choice("判別不能", .unknown, color: Theme.barIdle)
                Button("キャンセル", action: onCancel)
                    .font(.body)
                    .foregroundStyle(Theme.subtext)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(18)
            .frame(width: 300)
            .background(Theme.overlayCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.border, lineWidth: 1))
            // VoiceOver で後ろの画面に移らないようにし、2本指こすり（エスケープ）で閉じられるようにする
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onCancel)
        }
        .transition(.identity)
    }

    private func choice(_ title: String, _ overlap: BonusOverlap, color: Color) -> some View {
        Button {
            onPick(overlap)
        } label: {
            Text(title)
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// G数の帯をタップしたときに重ねて出す、総回転数の入力（アニメーションなし）
struct GamesOverlay: View {
    let model: CounterModel
    let onChange: () -> Void
    let onClose: () -> Void

    @State private var startText = ""
    @State private var currentText = ""
    @FocusState private var focused: Field?

    private enum Field {
        case start
        case current
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 14) {
                Text("総回転数（データカウンター）")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                field("打ち始め", text: $startText, field: .start) { model.setStartTotal($0) }
                field("現在", text: $currentText, field: .current) { model.setCurrentTotal($0) }
                HStack {
                    Text("自分のG数")
                        .foregroundStyle(Theme.subtext)
                    Spacer()
                    Text("\(model.totalGames)G")
                        .font(Theme.figure(24))
                        .foregroundStyle(Theme.led)
                }
                Button(action: onClose) {
                    Text("完了")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.led, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(maxWidth: 340)
            .background(Theme.overlayCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .padding(.top, 70)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onClose)
        }
        .transition(.identity)
        .onAppear {
            startText = model.current.startTotal.map(String.init) ?? ""
            currentText = model.current.currentTotal.map(String.init) ?? ""
            focused = model.current.startTotal == nil ? .start : .current
        }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        field: Field,
        commit: @escaping (Int?) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.subtext)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.figure(26))
                .foregroundStyle(Theme.text)
                .focused($focused, equals: field)
                .frame(maxWidth: 160)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits != newValue {
                        text.wrappedValue = digits
                        return
                    }
                    commit(digits.isEmpty ? nil : Int(digits))
                    onChange()
                }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .background(Theme.band, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
