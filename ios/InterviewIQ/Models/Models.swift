import Foundation

/// Row in `public.users`. `id` matches the Supabase auth user id.
struct UserProfile: Decodable, Equatable {
    let id: UUID
    let email: String
    let firstName: String?
    let lastName: String?
    let planType: String?
    let subscriptionStatus: String?
    let proUpgrade: Bool?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case planType = "plan_type"
        case subscriptionStatus = "subscription_status"
        case proUpgrade = "pro_upgrade"
        case createdAt = "created_at"
    }

    var isMonthly: Bool { planType?.lowercased() == "monthly" }
    var hasPro: Bool { proUpgrade == true }
    var planLabel: String { isMonthly ? "Unlimited Monthly" : "Single Session" }
}

struct InterviewScore: Decodable, Equatable, Identifiable {
    let id: UUID
    let category: String
    let score: Int
}

struct ImprovementNote: Decodable, Equatable, Identifiable {
    let id: UUID
    let note: String
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, note
        case sortOrder = "sort_order"
    }
}

/// One turn of an ElevenLabs conversation, as stored in `transcripts.transcript`.
/// Turns can carry many other keys (tool calls, metrics); only these are decoded.
struct TranscriptTurn: Decodable, Equatable {
    let role: String
    let message: String?
    let timeInCallSecs: Double?

    enum CodingKeys: String, CodingKey {
        case role, message
        case timeInCallSecs = "time_in_call_secs"
    }

    var isInterviewer: Bool { role == "agent" }
}

struct Transcript: Decodable, Equatable, Identifiable {
    let id: UUID
    let transcript: [TranscriptTurn]?
    let rawText: String?

    enum CodingKeys: String, CodingKey {
        case id, transcript
        case rawText = "raw_text"
    }

    /// Spoken turns only — drops tool-call turns that have no message.
    var spokenTurns: [TranscriptTurn] {
        (transcript ?? []).filter { !($0.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct Interview: Decodable, Equatable, Identifiable {
    let id: UUID
    let jobTitle: String?
    let companyName: String?
    let overallScore: Int?
    let statusLabel: String?
    let overallVerdict: String?
    let status: String?
    let interviewDate: Date?
    let scores: [InterviewScore]
    let notes: [ImprovementNote]
    let transcripts: [Transcript]

    enum CodingKeys: String, CodingKey {
        case id
        case jobTitle = "job_title"
        case companyName = "company_name"
        case overallScore = "overall_score"
        case statusLabel = "status_label"
        case overallVerdict = "overall_verdict"
        case status
        case interviewDate = "interview_date"
        case scores = "interview_scores"
        case notes = "improvement_notes"
        case transcripts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        jobTitle = try c.decodeIfPresent(String.self, forKey: .jobTitle)
        companyName = try c.decodeIfPresent(String.self, forKey: .companyName)
        overallScore = try c.decodeIfPresent(Int.self, forKey: .overallScore)
        statusLabel = try c.decodeIfPresent(String.self, forKey: .statusLabel)
        overallVerdict = try c.decodeIfPresent(String.self, forKey: .overallVerdict)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        interviewDate = try c.decodeIfPresent(Date.self, forKey: .interviewDate)
        scores = try c.decodeIfPresent([InterviewScore].self, forKey: .scores) ?? []
        notes = (try c.decodeIfPresent([ImprovementNote].self, forKey: .notes) ?? [])
            .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        transcripts = try c.decodeIfPresent([Transcript].self, forKey: .transcripts) ?? []
    }

    var displayTitle: String { jobTitle?.isEmpty == false ? jobTitle! : "Interview" }
    var transcript: Transcript? { transcripts.first }
    /// Only interviews that have been scored count toward stats and the dashboard.
    var isScored: Bool { overallScore != nil }
}

extension Interview: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Array where Element == Interview {
    var scored: [Interview] { filter(\.isScored) }

    var averageScore: Int? {
        let values = compactMap(\.overallScore)
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

extension Date {
    var shortDisplay: String { formatted(.dateTime.month(.abbreviated).day().year()) }
}
