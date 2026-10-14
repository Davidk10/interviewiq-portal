import SwiftUI

struct ReportView: View {
    @Environment(AppModel.self) private var model
    let interview: Interview

    enum ReportSection: String, CaseIterable, Identifiable {
        case scores = "Scores", improvements = "Improvements", transcript = "Transcript"
        var id: Self { self }
    }

    @State private var section: ReportSection = .scores

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                header
                Picker("Section", selection: $section) {
                    ForEach(ReportSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Group {
                    switch section {
                    case .scores: scores
                    case .improvements: improvements
                    case .transcript: transcript
                    }
                }
                .card()
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(interview.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: section)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ScoreRing(score: interview.overallScore, size: 150, lineWidth: 14)
            StatusText(label: interview.statusLabel)
            Text([interview.companyName, interview.interviewDate?.shortDisplay].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
            if let verdict = interview.overallVerdict, !verdict.isEmpty {
                Text(verdict)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var scores: some View {
        if interview.scores.isEmpty {
            Text("Score breakdown not available yet.").foregroundStyle(Theme.textMuted)
        } else {
            VStack(spacing: 16) {
                ForEach(interview.scores) { ScoreBar(label: $0.category, score: $0.score) }
            }
        }
    }

    @ViewBuilder private var improvements: some View {
        if interview.notes.isEmpty {
            Text("Improvement notes not available yet.").foregroundStyle(Theme.textMuted)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(interview.notes) { NoteRow(text: $0.note) }
            }
        }
    }

    @ViewBuilder private var transcript: some View {
        if model.profile?.isMember != true {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill").font(.title).foregroundStyle(Theme.purple)
                Text("Transcripts are for members")
                    .font(.headline)
                Text("Unlimited Monthly members can read the full conversation from every interview.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else if let turns = interview.transcript?.spokenTurns, !turns.isEmpty {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(Array(turns.enumerated()), id: \.offset) { _, turn in
                    TranscriptBubble(turn: turn)
                }
            }
        } else if let raw = interview.transcript?.rawText, !raw.isEmpty {
            Text(raw).font(.subheadline).foregroundStyle(Color(hex: 0xD1D5DB))
        } else {
            Text("Transcript not available for this session.").foregroundStyle(Theme.textMuted)
        }
    }
}

private struct TranscriptBubble: View {
    let turn: TranscriptTurn

    var body: some View {
        VStack(alignment: turn.isInterviewer ? .leading : .trailing, spacing: 4) {
            Text(turn.isInterviewer ? "AI Interviewer" : "You")
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(turn.isInterviewer ? Theme.cyan : Theme.textSecondary)
            Text(turn.message ?? "")
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0xE5E7EB))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(turn.isInterviewer ? Theme.cardRaised : Theme.cyan.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: turn.isInterviewer ? .leading : .trailing)
        .padding(turn.isInterviewer ? .trailing : .leading, 32)
    }
}
