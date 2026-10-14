import Foundation
import Supabase

/// Single shared Supabase client for the app.
let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey,
    options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
)

/// Reads the signed-in member's data. Row Level Security limits every query to their own rows.
enum InterviewRepository {
    static func profile(userID: UUID) async throws -> UserProfile? {
        let rows: [UserProfile] = try await supabase
            .from("users")
            .select("id, email, first_name, last_name, plan_type, subscription_status, pro_upgrade, created_at")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func interviews(userID: UUID) async throws -> [Interview] {
        try await supabase
            .from("interviews")
            .select("""
                id, job_title, company_name, overall_score, status_label, overall_verdict, status, interview_date,
                interview_scores(id, category, score),
                improvement_notes(id, note, sort_order),
                transcripts(id, transcript, raw_text)
                """)
            .eq("user_id", value: userID.uuidString)
            .order("interview_date", ascending: false)
            .execute()
            .value
    }
}
