import XCTest
@testable import InterviewIQ

final class ModelTests: XCTestCase {
    private func decodeInterviews(_ json: String) throws -> [Interview] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Interview].self, from: Data(json.utf8))
    }

    func testDecodesInterviewWithNestedRowsAndElevenLabsTranscript() throws {
        let json = """
        [{
          "id": "6f1c1d2e-0000-4000-8000-000000000001",
          "job_title": "Product Manager", "company_name": "Acme", "overall_score": 82,
          "status_label": "Strong Candidate", "overall_verdict": null, "status": "sent",
          "interview_date": "2026-10-01T15:00:00Z",
          "interview_scores": [{"id": "6f1c1d2e-0000-4000-8000-000000000002", "category": "Communication", "score": 88}],
          "improvement_notes": [
            {"id": "6f1c1d2e-0000-4000-8000-000000000004", "note": "Second", "sort_order": 2},
            {"id": "6f1c1d2e-0000-4000-8000-000000000003", "note": "First", "sort_order": 1}
          ],
          "transcripts": [{
            "id": "6f1c1d2e-0000-4000-8000-000000000005",
            "raw_text": null,
            "transcript": [
              {"role": "agent", "message": "Tell me about yourself.", "time_in_call_secs": 1, "tool_calls": []},
              {"role": "agent", "message": null, "tool_calls": [{"name": "end_call"}]},
              {"role": "user", "message": "I lead product at Acme.", "time_in_call_secs": 4}
            ]
          }]
        }]
        """
        let interview = try XCTUnwrap(decodeInterviews(json).first)
        XCTAssertEqual(interview.overallScore, 82)
        XCTAssertEqual(interview.scores.first?.category, "Communication")
        XCTAssertEqual(interview.notes.map(\.note), ["First", "Second"])
        XCTAssertEqual(interview.transcript?.spokenTurns.count, 2)
        XCTAssertTrue(interview.transcript?.spokenTurns.first?.isInterviewer == true)
    }

    func testMissingNestedArraysDefaultToEmpty() throws {
        let json = #"[{"id": "6f1c1d2e-0000-4000-8000-000000000001", "overall_score": null}]"#
        let interview = try XCTUnwrap(decodeInterviews(json).first)
        XCTAssertFalse(interview.isScored)
        XCTAssertTrue(interview.scores.isEmpty)
        XCTAssertNil(interview.transcript)
        XCTAssertEqual(interview.displayTitle, "Interview")
    }

    func testAverageIgnoresUnscoredInterviews() throws {
        let json = """
        [{"id": "6f1c1d2e-0000-4000-8000-000000000001", "overall_score": 80},
         {"id": "6f1c1d2e-0000-4000-8000-000000000002", "overall_score": 71},
         {"id": "6f1c1d2e-0000-4000-8000-000000000003", "overall_score": null}]
        """
        let interviews = try decodeInterviews(json)
        XCTAssertEqual(interviews.scored.count, 2)
        XCTAssertEqual(interviews.averageScore, 76) // 75.5 rounds up
        XCTAssertNil([Interview]().averageScore)
    }

    func testScoreStatusBands() {
        XCTAssertEqual(ScoreStatus(label: "Top Candidate"), .top)
        XCTAssertEqual(ScoreStatus(label: "Strong Candidate"), .strong)
        XCTAssertEqual(ScoreStatus(label: "Good"), .good)
        XCTAssertEqual(ScoreStatus(label: nil), .good)
        XCTAssertEqual(ScoreStatus(label: "Needs Work"), .needsWork)
    }
}
