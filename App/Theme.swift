import SwiftUI
import UIKit

/// 実戦画面の色と文字（デザイン案 D：C の片手配置 + A の上の帯・設定推測）
enum Theme {
    static let background = Color(hex: 0x0B0B0F)
    static let surface = Color(hex: 0x17171D)
    static let band = Color(hex: 0x121217)
    static let line = Color(hex: 0x2A2A33)
    static let border = Color(hex: 0x3A3A45)
    static let overlayCard = Color(hex: 0x22222A)
    static let text = Color(hex: 0xF2F2F5)
    static let subtext = Color(hex: 0xA0A0AE)
    static let softText = Color(hex: 0xC9C9D3)
    /// 帯の数字と設定推測の強調。強すぎないよう少し柔らかいアンバー
    static let led = Color(hex: 0xF2C46D)
    static let barIdle = Color(hex: 0x4A4A57)
    /// 設定推測の棒（最有力以外）。背景 #17171D に対して 3.5:1 を確保
    static let barMuted = Color(hex: 0x6E6E7C)
    static let ok = Color(hex: 0x7BE0A0)

    /// 上の帯（G数・ボーナス合算・ぶどう合算）の数字。案 B の太い数字
    static func figure(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy)
    }

    /// ボタンの回数の数字。ドット文字（DotGothic16）を同梱していればそれを使い、なければ等幅の太字
    static func counter(_ size: CGFloat) -> Font {
        if UIFont(name: "DotGothic16-Regular", size: size) != nil {
            return .custom("DotGothic16-Regular", size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Role {
    /// 実戦画面の大きなボタンの面（黒に近い、ほんのり色の付いた面。ベタ塗りの原色は使わない）
    var tileBackground: Color {
        switch self {
        case .grape: Color(hex: 0x1E1830)
        case .cherry: Color(hex: 0x2A1820)
        case .big: Color(hex: 0x2B1A19)
        case .reg: Color(hex: 0x17213A)
        case .bell: Color(hex: 0x2A2412)
        case .watermelon: Color(hex: 0x15281C)
        case .chance: Color(hex: 0x2C1F14)
        }
    }

    /// ボタンの細い枠
    var tileBorder: Color {
        switch self {
        case .grape: Color(hex: 0x4A3A78)
        case .cherry: Color(hex: 0x6E3346)
        case .big: Color(hex: 0x7A3530)
        case .reg: Color(hex: 0x2F4F86)
        case .bell: Color(hex: 0x6B5A22)
        case .watermelon: Color(hex: 0x2F6B45)
        case .chance: Color(hex: 0x7A4A22)
        }
    }

    /// ボタンの名前の文字色（面に対して 8:1 以上）
    var tileLabel: Color {
        switch self {
        case .grape: Color(hex: 0xC3B1F0)
        case .cherry: Color(hex: 0xF0A8B8)
        case .big: Color(hex: 0xF2A49C)
        case .reg: Color(hex: 0x9EC2F2)
        case .bell: Color(hex: 0xE8D08A)
        case .watermelon: Color(hex: 0x9ED9B0)
        case .chance: Color(hex: 0xF0B98A)
        }
    }
}
