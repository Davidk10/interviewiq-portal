import XCTest
@testable import InterviewIQ

final class BookingTests: XCTestCase {
    func testPhoneNumbersAreConvertedToE164() {
        XCTAssertEqual(PhoneNumber.e164(from: "(555) 123-4567"), "+15551234567")
        XCTAssertEqual(PhoneNumber.e164(from: "1 555 123 4567"), "+15551234567")
        XCTAssertEqual(PhoneNumber.e164(from: "+44 20 7946 0958"), "+442079460958")
        XCTAssertNil(PhoneNumber.e164(from: "12345"))
        XCTAssertNil(PhoneNumber.e164(from: ""))
        XCTAssertEqual(PhoneNumber.display("+15551234567"), "(555) 123-4567")
        XCTAssertEqual(PhoneNumber.display("+442079460958"), "+442079460958")
    }

    func testJobLinkIsAddedToBookingDescription() {
        var draft = JobDraft()
        draft.title = "Forklift Operator"
        XCTAssertNil(draft.descriptionForBooking)

        draft.link = "https://example.com/job/1"
        XCTAssertEqual(draft.descriptionForBooking, "Job posting: https://example.com/job/1")

        draft.description = "Drive forklifts."
        XCTAssertEqual(draft.descriptionForBooking, "Drive forklifts.\n\nJob posting: https://example.com/job/1")
    }

    func testDraftNeedsATitle() {
        var draft = JobDraft()
        draft.title = "   "
        XCTAssertFalse(draft.isComplete)
        draft.title = "Welder"
        XCTAssertTrue(draft.isComplete)
    }

    func testReadsSchemaOrgJobPosting() {
        let html = """
        <html><head><title>Ignored</title>
        <script type="application/ld+json">
        {"@context":"https://schema.org","@type":"JobPosting","title":"Warehouse Lead",
         "hiringOrganization":{"@type":"Organization","name":"Acme &amp; Co"},
         "description":"<p>Lead a team of 10.</p><ul><li>Forklift certified</li></ul>"}
        </script></head></html>
        """
        let draft = JobLinkReader.parse(html: html)
        XCTAssertEqual(draft.title, "Warehouse Lead")
        XCTAssertEqual(draft.company, "Acme & Co")
        XCTAssertTrue(draft.description.contains("Lead a team of 10."))
        XCTAssertTrue(draft.description.contains("• Forklift certified"))
    }

    func testFallsBackToOpenGraphTags() {
        let html = """
        <meta property="og:title" content="CNC Machinist - Springfield" />
        <meta content="Run 5-axis mills." name="description">
        <meta property="og:site_name" content="Globex Careers">
        """
        let draft = JobLinkReader.parse(html: html)
        XCTAssertEqual(draft.title, "CNC Machinist - Springfield")
        XCTAssertEqual(draft.description, "Run 5-axis mills.")
        XCTAssertEqual(draft.company, "Globex Careers")
    }

    func testRecognisesKESJobBoardLinks() {
        XCTAssertEqual(JobLinkReader.kesJobSlug(URL(string: "https://jobs.kestechgroup.com/jobs/forklift-operator-123")!),
                       "forklift-operator-123")
        XCTAssertNil(JobLinkReader.kesJobSlug(URL(string: "https://example.com/jobs/abc")!))
        XCTAssertEqual(JobLinkReader.normalizedURL("indeed.com/viewjob?jk=1")?.absoluteString, "https://indeed.com/viewjob?jk=1")
        XCTAssertNil(JobLinkReader.normalizedURL("not a link"))
    }

    func testMembershipRules() throws {
        func profile(_ account: String, _ plan: String, _ status: String) throws -> UserProfile {
            let json = """
            {"id":"6f1c1d2e-0000-4000-8000-000000000001","email":"a@b.co","account_type":"\(account)",
             "plan_type":"\(plan)","subscription_status":"\(status)"}
            """
            return try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        }
        let member = try profile("monthly", "monthly", "active")
        XCTAssertTrue(member.isMember)
        XCTAssertTrue(member.canBookInterviews)
        let pastDue = try profile("monthly", "monthly", "past_due")
        XCTAssertFalse(pastDue.isMember)
        XCTAssertTrue(pastDue.canBookInterviews)
        let free = try profile("free", "single", "active")
        XCTAssertFalse(free.isMember)
        XCTAssertFalse(free.canBookInterviews)
        XCTAssertEqual(free.planLabel, "Free")
    }
}
