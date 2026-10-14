import SwiftUI

/// Pro upgrade screen. Purchasing via Apple in-app purchase (StoreKit 2) is added in the payments milestone.
struct ProView: View {
    @Environment(AppModel.self) private var model

    private let features: [(symbol: String, title: String, detail: String)] = [
        ("graduationcap.fill", "AI Coaching Plan", "Personalized drills targeting your weakest interview areas."),
        ("doc.text.fill", "Resume Improvement", "ATS-optimized rewrite aligned to your target roles."),
        ("map.fill", "Career Path Advisor", "Roadmap of roles, certs, and milestones to your 2-year goal."),
        ("text.bubble.fill", "Annotated Transcripts", "Read every interview with moment-by-moment feedback."),
        ("sparkles", "All Future Features", "Every new Pro feature included automatically."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    if model.profile?.hasPro == true {
                        EmptyStateView(symbol: "checkmark.seal.fill",
                                       title: "You're a Pro member",
                                       message: "All features are unlocked. Enjoy your full coaching suite.")
                            .card()
                    } else {
                        offer
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Pro")
        }
    }

    private var offer: some View {
        VStack(alignment: .leading, spacing: 20) {
            Pill(text: "ONE-TIME UPGRADE", color: Theme.cyan)
            VStack(alignment: .leading, spacing: 4) {
                Text("InterviewIQ Pro").font(.title.bold())
                Text("Unlock every coaching tool. No recurring fees.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                ForEach(features, id: \.title) { feature in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: feature.symbol)
                            .font(.title3)
                            .foregroundStyle(Theme.brandGradient)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title).font(.subheadline.weight(.semibold))
                            Text(feature.detail).font(.footnote).foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }
            Button("Coming soon") {}
                .buttonStyle(.primary)
                .disabled(true)
            Text("Pro will be available to purchase in the app soon.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Theme.proGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cyan.opacity(0.6)))
    }
}
