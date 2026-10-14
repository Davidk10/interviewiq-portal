import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: "https://vadpkpvbtybsfsygarup.supabase.co")!
    // Public anon key (same as the web portal). Row Level Security protects the data.
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhZHBrcHZidHlic2ZzeWdhcnVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NjAxMTYsImV4cCI6MjA5MjAzNjExNn0.7N5wP9z1HvzqajVq6iJre3pMvHiubi0YXkUK-ik9VTA"

    /// Must match Supabase → Authentication → Sign In / Providers → Email → "Email OTP Length".
    static let signInCodeLength = 8

    static let supportEmail = "Support@Kestechgroup.com"
    static let bookInterviewURL = URL(string: "https://kestechgroup.com/interviewiq")!
    static let supportURL = URL(string: "mailto:Support@Kestechgroup.com")!
}
