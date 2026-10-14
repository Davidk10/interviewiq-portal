import Foundation
import Supabase

/// Reads the public KES job board. Only `status = 'active'` rows are readable.
enum JobService {
    static let pageSize = 30

    static func search(text: String, category: String?, page: Int) async throws -> [Job] {
        var query = supabase
            .from("jobs")
            .select(Job.columns)
            .eq("status", value: "active")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            query = query.textSearch("fts", query: trimmed, config: "english", type: .websearch)
        }
        if let category {
            query = query.eq("category", value: category)
        }
        let from = page * pageSize
        return try await query
            .order("posted_at", ascending: false, nullsFirst: false)
            .range(from: from, to: from + pageSize - 1)
            .execute()
            .value
    }

    static func job(slug: String) async throws -> Job? {
        let rows: [Job] = try await supabase
            .from("jobs")
            .select(Job.columns)
            .eq("status", value: "active")
            .eq("slug", value: slug)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}

/// Books AI mock interview calls through the same database functions the web portal uses.
enum BookingService {
    private struct BookParams: Encodable {
        let p_job_title: String
        let p_company_name: String?
        let p_job_description: String?
        let p_interview_date: String
        let p_timezone: String
    }

    private struct ProfileParams: Encodable {
        let p_phone: String
    }

    /// `date == nil` means call now. The server's dispatcher runs every minute and dials
    /// any paid interview whose time has arrived, so "now" rings within about a minute.
    static func book(_ draft: JobDraft, at date: Date?) async throws {
        let params = BookParams(
            p_job_title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            p_company_name: draft.company.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            p_job_description: draft.descriptionForBooking,
            p_interview_date: ISO8601DateFormatter().string(from: date ?? .now),
            p_timezone: TimeZone.current.identifier
        )
        try await supabase.rpc("book_monthly_interview", params: params).execute()
    }

    /// Saves the number the interviewer will call (`public.users.phone`).
    static func savePhone(_ e164: String) async throws {
        try await supabase.rpc("update_own_profile", params: ProfileParams(p_phone: e164)).execute()
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
