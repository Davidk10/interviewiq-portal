import SwiftUI

/// Brand colours, matching the web portal.
enum Theme {
    static let background = Color(hex: 0x0F1117)
    static let card = Color(hex: 0x161B27)
    static let cardRaised = Color(hex: 0x1F2937)
    static let border = Color(hex: 0x1F2937)

    static let cyan = Color(hex: 0x06B6D4)
    static let blue = Color(hex: 0x3B82F6)
    static let indigo = Color(hex: 0x818CF8)
    static let violet = Color(hex: 0xA78BFA)
    static let purple = Color(hex: 0xA855F7)

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x9CA3AF)
    static let textMuted = Color(hex: 0x6B7280)
    static let textFaint = Color(hex: 0x4B5563)

    static let success = Color(hex: 0x10B981)
    static let warning = Color(hex: 0xF59E0B)
    static let danger = Color(hex: 0xEF4444)

    static let brandGradient = LinearGradient(colors: [cyan, blue], startPoint: .leading, endPoint: .trailing)
    static let proGradient = LinearGradient(colors: [Color(hex: 0x0F1F35), Color(hex: 0x150A2E)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)

    static let cornerRadius: CGFloat = 16
    static let spacing: CGFloat = 16
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Interview result bands, derived from the free-text `status_label` the scorer writes.
enum ScoreStatus: Equatable {
    case top, strong, good, needsWork

    init(label: String?) {
        let l = (label ?? "").lowercased()
        if l.contains("top") { self = .top }
        else if l.contains("strong") { self = .strong }
        else if l.contains("good") || l.isEmpty { self = .good }
        else { self = .needsWork }
    }

    var color: Color {
        switch self {
        case .top: Theme.success
        case .strong: Theme.cyan
        case .good: Theme.warning
        case .needsWork: Theme.danger
        }
    }
}
