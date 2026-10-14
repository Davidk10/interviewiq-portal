import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.interviews.isEmpty {
                        EmptyStateView(symbol: "tray",
                                       title: "No interviews on record yet",
                                       message: "Completed interviews and their reports will be listed here.")
                    }
                    ForEach(model.interviews) { interview in
                        NavigationLink(value: interview) { HistoryRow(interview: interview) }
                            .buttonStyle(.plain)
                            .disabled(!interview.isScored)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .refreshable { await model.refresh() }
            .screenBackground()
            .navigationTitle("History")
            .navigationDestination(for: Interview.self) { ReportView(interview: $0) }
        }
    }
}

struct HistoryRow: View {
    let interview: Interview

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(interview.overallScore.map(String.init) ?? "—")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brandGradient)
                Text("/100").font(.caption2).foregroundStyle(Theme.textFaint)
            }
            .frame(minWidth: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(interview.displayTitle).font(.body.weight(.semibold)).lineLimit(2)
                if let company = interview.companyName, !company.isEmpty {
                    Text(company).font(.subheadline).foregroundStyle(Theme.textMuted)
                }
                HStack(spacing: 8) {
                    if let date = interview.interviewDate {
                        Text(date.shortDisplay).font(.caption).foregroundStyle(Theme.textFaint)
                    }
                    if interview.isScored {
                        StatusText(label: interview.statusLabel)
                    } else {
                        Text(pendingLabel).font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
            if interview.isScored {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textFaint)
            }
        }
        .card(padding: 16)
        .contentShape(Rectangle())
    }

    private var pendingLabel: String {
        switch interview.status {
        case "needs_reschedule": "Needs rescheduling"
        case "canceled": "Canceled"
        case "scheduled", "paid": "Scheduled"
        default: "Report in progress"
        }
    }
}
