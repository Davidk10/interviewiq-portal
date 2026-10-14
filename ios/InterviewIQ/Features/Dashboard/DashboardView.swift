import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    greeting
                    if let error = model.loadError { errorBanner(error) }
                    statsRow
                    if let latest = model.interviews.scored.first {
                        NavigationLink(value: latest) { latestReport(latest) }
                            .buttonStyle(.plain)
                        if model.interviews.scored.count >= 2 { trendCard }
                        improvements(latest)
                        bookButton
                    } else {
                        EmptyStateView(symbol: "waveform.circle",
                                       title: "No interviews yet",
                                       message: "Your interview reports will appear here after your first session.")
                            .card()
                        bookButton
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .refreshable { await model.refresh() }
            .screenBackground()
            .navigationTitle("Dashboard")
            .toolbar { ToolbarItem(placement: .topBarLeading) { BrandMark(size: 15) } }
            .navigationDestination(for: Interview.self) { ReportView(interview: $0) }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome back, \(model.displayName)")
                .font(.title3.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.top, 4)
    }

    private var subtitle: String {
        let count = model.interviews.scored.count
        switch count {
        case 0: return "You haven't completed any interviews yet."
        case 1: return "You've completed 1 interview."
        default: return "You've completed \(count) interviews."
        }
    }

    private var statsRow: some View {
        let scored = model.interviews.scored
        return HStack(spacing: 10) {
            StatTile(title: "Latest", value: scored.first?.overallScore.map { "\($0)" } ?? "—",
                     style: AnyShapeStyle(Theme.brandGradient))
            StatTile(title: "Interviews", value: "\(scored.count)", style: AnyShapeStyle(Theme.indigo))
            StatTile(title: "Average", value: scored.averageScore.map { "\($0)" } ?? "—",
                     style: AnyShapeStyle(Theme.violet))
        }
    }

    private func latestReport(_ interview: Interview) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Latest Report").font(.headline)
                    Text([interview.jobTitle, interview.companyName].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                    StatusText(label: interview.statusLabel).padding(.top, 6)
                }
                Spacer(minLength: 12)
                ScoreRing(score: interview.overallScore, size: 92, lineWidth: 9)
            }
            ForEach(interview.scores) { ScoreBar(label: $0.category, score: $0.score) }
            HStack(spacing: 4) {
                Text("View full report")
                Image(systemName: "chevron.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.cyan)
        }
        .card()
    }

    private var trendCard: some View {
        // Oldest → newest so the line reads left to right.
        let points = model.interviews.scored.prefix(10).reversed().enumerated().map { index, interview in
            TrendPoint(id: interview.id, session: index + 1, score: interview.overallScore ?? 0)
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Score Trend").font(.headline)
            Chart(points) { point in
                LineMark(x: .value("Session", point.session), y: .value("Score", point.score))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.brandGradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                PointMark(x: .value("Session", point.session), y: .value("Score", point.score))
                    .foregroundStyle(Theme.cyan)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .frame(height: 140)
        }
        .card()
    }

    private func improvements(_ interview: Interview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Areas to Improve", systemImage: "target")
                .font(.headline)
            if interview.notes.isEmpty {
                Text("Improvement tips will appear here after your interview is analyzed.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
            } else {
                ForEach(interview.notes) { NoteRow(text: $0.note) }
            }
        }
        .card()
    }

    private var bookButton: some View {
        Button {
            model.startBooking()
        } label: {
            Label("Book an Interview", systemImage: "phone.fill")
        }
        .buttonStyle(.primary)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(Theme.warning)
            .card(padding: 14)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let style: AnyShapeStyle

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Theme.textMuted)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(style)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border))
        .accessibilityElement(children: .combine)
    }
}

private struct TrendPoint: Identifiable {
    let id: UUID
    let session: Int
    let score: Int
}

struct NoteRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color(hex: 0xE5E7EB))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
            .overlay(alignment: .leading) { Capsule().fill(Theme.cyan).frame(width: 3) }
    }
}
