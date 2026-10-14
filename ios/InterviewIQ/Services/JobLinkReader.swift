import Foundation

/// Fills in job details from a pasted posting link.
///
/// KES job board links are looked up in the database. Other sites are fetched and read from their
/// schema.org `JobPosting` data (which most job boards publish for Google Jobs), falling back to
/// the page's Open Graph title and description.
enum JobLinkReader {
    enum ReadError: LocalizedError {
        case invalidLink
        case nothingFound

        var errorDescription: String? {
            switch self {
            case .invalidLink: "That doesn't look like a web link."
            case .nothingFound: "We couldn't read that page. Enter the job title below instead."
            }
        }
    }

    static func normalizedURL(_ text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        if !trimmed.lowercased().hasPrefix("http") { trimmed = "https://" + trimmed }
        guard let url = URL(string: trimmed), let host = url.host, host.contains(".") else { return nil }
        return url
    }

    static func read(_ text: String) async throws -> JobDraft {
        guard let url = normalizedURL(text) else { throw ReadError.invalidLink }

        if let slug = kesJobSlug(url), let job = try? await JobService.job(slug: slug) {
            var draft = JobDraft(job: job)
            draft.link = url.absoluteString
            return draft
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        // Some job sites only serve full HTML to browser-like agents.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(decoding: data.prefix(3_000_000), as: UTF8.self)

        var draft = parse(html: html)
        draft.link = url.absoluteString
        guard draft.isComplete else { throw ReadError.nothingFound }
        return draft
    }

    /// `https://jobs.kestechgroup.com/jobs/<slug>` → `<slug>`
    static func kesJobSlug(_ url: URL) -> String? {
        guard url.host?.lowercased() == "jobs.kestechgroup.com" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "jobs" else { return nil }
        return parts[1].removingPercentEncoding ?? parts[1]
    }

    static func parse(html: String) -> JobDraft {
        var draft = JobDraft()
        if let posting = jobPosting(in: html) {
            draft.title = clean(posting["title"] as? String)
            if let org = posting["hiringOrganization"] as? [String: Any] {
                draft.company = clean(org["name"] as? String)
            } else if let org = posting["hiringOrganization"] as? String {
                draft.company = clean(org)
            }
            draft.description = clean(posting["description"] as? String)
        }
        if draft.title.isEmpty {
            draft.title = clean(metaContent(html, property: "og:title") ?? titleTag(html))
        }
        if draft.description.isEmpty {
            draft.description = clean(metaContent(html, property: "og:description")
                                      ?? metaContent(html, property: "description"))
        }
        if draft.company.isEmpty {
            draft.company = clean(metaContent(html, property: "og:site_name"))
        }
        return draft
    }

    // MARK: - HTML helpers

    private static func jobPosting(in html: String) -> [String: Any]? {
        let pattern = #"<script[^>]*application/ld\+json[^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard let r = Range(match.range(at: 1), in: html),
                  let data = html[r].data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let found = findJobPosting(json) { return found }
        }
        return nil
    }

    private static func findJobPosting(_ json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            let type = dict["@type"]
            if (type as? String) == "JobPosting" || (type as? [String])?.contains("JobPosting") == true {
                return dict
            }
            if let graph = dict["@graph"] { return findJobPosting(graph) }
        } else if let array = json as? [Any] {
            for item in array { if let found = findJobPosting(item) { return found } }
        }
        return nil
    }

    private static func metaContent(_ html: String, property: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: property)
        let patterns = [
            #"<meta[^>]+(?:property|name)=["']\#(escaped)["'][^>]*content=["']([^"']*)["']"#,
            #"<meta[^>]+content=["']([^"']*)["'][^>]*(?:property|name)=["']\#(escaped)["']"#,
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern, in: html), !value.isEmpty { return value }
        }
        return nil
    }

    private static func titleTag(_ html: String) -> String? {
        firstCapture(#"<title[^>]*>(.*?)</title>"#, in: html)
    }

    private static func firstCapture(_ pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    /// Strips tags and decodes common HTML entities; job descriptions are often HTML.
    static func clean(_ text: String?) -> String {
        guard var s = text else { return "" }
        s = s.replacingOccurrences(of: #"<br\s*/?>|</p>|</li>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<li>", with: "• ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&apos;": "'", "&nbsp;": " "]
        for (entity, char) in entities { s = s.replacingOccurrences(of: entity, with: char) }
        s = s.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\n\s*\n\s*\n+"#, with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
