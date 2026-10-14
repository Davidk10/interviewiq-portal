import SwiftUI

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(Theme.border))
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View { modifier(CardModifier(padding: padding)) }

    /// Standard screen background used by every tab.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

// MARK: - Brand mark

struct BrandMark: View {
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 8) {
            Text("KES").font(.system(size: size, weight: .heavy)).foregroundStyle(Theme.cyan)
            Text("/").font(.system(size: size)).foregroundStyle(Theme.textFaint)
            Text("InterviewIQ").font(.system(size: size, weight: .bold))
        }
    }
}

// MARK: - Score visuals

/// Circular score gauge, 0–100.
struct ScoreRing: View {
    let score: Int?
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Theme.cardRaised, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(AngularGradient(colors: [Theme.cyan, Theme.blue, Theme.cyan], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(score.map(String.init) ?? "—")
                    .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brandGradient)
                    .contentTransition(.numericText())
                Text("/100").font(.system(size: size * 0.11)).foregroundStyle(Theme.textFaint)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(duration: 1.0)) { animatedProgress = Double(score ?? 0) / 100 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score.map { "Score \($0) out of 100" } ?? "No score yet")
    }
}

/// Labelled horizontal bar for a category score.
struct ScoreBar: View {
    let label: String
    let score: Int

    @State private var animatedWidth: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(Color(hex: 0xD1D5DB))
                Spacer()
                Text("\(score)/100").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.cyan)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cardRaised)
                    Capsule().fill(Theme.brandGradient)
                        .frame(width: geo.size.width * animatedWidth)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { animatedWidth = Double(min(max(score, 0), 100)) / 100 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(score) out of 100")
    }
}

struct StatusText: View {
    let label: String?

    var body: some View {
        if let label, !label.isEmpty {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ScoreStatus(label: label).color)
        }
    }
}

// MARK: - Badges

struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Empty / error states

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(Theme.brandGradient)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}
