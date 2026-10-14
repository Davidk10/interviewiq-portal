import Foundation

/// Active listing on the KES job board (`public.jobs`).
struct Job: Decodable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let slug: String
    let description: String?
    let category: String?
    let employmentType: String?
    let city: String?
    let state: String?
    let isRemote: Bool?
    let salaryMin: Double?
    let salaryMax: Double?
    let salaryPeriod: String?
    let sourceURL: String?
    let postedAt: Date?
    let company: Company?

    struct Company: Decodable, Hashable {
        let name: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, category, city, state
        case employmentType = "employment_type"
        case isRemote = "is_remote"
        case salaryMin = "salary_min"
        case salaryMax = "salary_max"
        case salaryPeriod = "salary_period"
        case sourceURL = "source_url"
        case postedAt = "posted_at"
        case company = "companies"
    }

    /// Columns to select, including the company name through the `company_id` foreign key.
    static let columns = """
        id, title, slug, description, category, employment_type, city, state, is_remote,
        salary_min, salary_max, salary_period, source_url, posted_at, companies:company_id(name)
        """

    static let categories: [(value: String, label: String)] = [
        ("warehouse", "Warehouse"),
        ("manufacturing", "Manufacturing"),
        ("logistics", "Logistics"),
        ("skilled_trades", "Skilled Trades"),
        ("engineering", "Engineering"),
        ("supervision", "Supervision"),
    ]

    var companyName: String? { company?.name?.isEmpty == false ? company?.name : nil }

    var categoryLabel: String? {
        Job.categories.first { $0.value == category }?.label
    }

    var location: String? {
        if isRemote == true { return "Remote" }
        let parts = [city, state].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var salaryText: String? {
        guard salaryMin != nil || salaryMax != nil else { return nil }
        func money(_ value: Double) -> String {
            value >= 1000
                ? "$" + (value / 1000).formatted(.number.precision(.fractionLength(0...1))) + "k"
                : value.formatted(.currency(code: "USD").precision(.fractionLength(0...2)))
        }
        let range = [salaryMin, salaryMax].compactMap { $0 }.map(money).joined(separator: "–")
        let period: String = switch salaryPeriod?.lowercased() {
        case "hour", "hourly": "/hr"
        case "year", "yearly", "annual": "/yr"
        case "month", "monthly": "/mo"
        default: ""
        }
        return range + period
    }

    /// Public posting page: the original source if there is one, otherwise the KES job board page.
    var postingURL: URL? {
        if let sourceURL, let url = URL(string: sourceURL) { return url }
        return URL(string: "https://jobs.kestechgroup.com/jobs/\(slug)")
    }
}

/// The role a member wants to practice for, from any of the three entry methods.
struct JobDraft: Equatable {
    var title = ""
    var company = ""
    var description = ""
    var link = ""

    init() {}

    init(job: Job) {
        title = job.title
        company = job.companyName ?? ""
        description = job.description ?? ""
        link = job.postingURL?.absoluteString ?? ""
    }

    var isComplete: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Description sent to the interviewer. The booking function has no job-link parameter,
    /// so the link is appended to the description where the interview workflow can read it.
    var descriptionForBooking: String? {
        var text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty && !text.contains(url) {
            text += (text.isEmpty ? "" : "\n\n") + "Job posting: \(url)"
        }
        return text.isEmpty ? nil : text
    }
}

enum PhoneNumber {
    /// Converts what a member types into E.164 (`+15551234567`), which the calling service requires.
    /// US numbers can be entered without a country code. Returns nil if it doesn't look like a phone number.
    static func e164(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter(\.isNumber)
        if trimmed.hasPrefix("+") {
            return (8...15).contains(digits.count) ? "+" + digits : nil
        }
        if digits.count == 10 { return "+1" + digits }
        if digits.count == 11 && digits.hasPrefix("1") { return "+" + digits }
        return nil
    }

    /// `+15551234567` → `(555) 123-4567`; other countries are shown as stored.
    static func display(_ e164: String) -> String {
        let digits = e164.filter(\.isNumber)
        guard digits.count == 11, digits.hasPrefix("1") else { return e164 }
        let d = Array(digits.dropFirst())
        return "(\(String(d[0..<3]))) \(String(d[3..<6]))-\(String(d[6..<10]))"
    }
}
