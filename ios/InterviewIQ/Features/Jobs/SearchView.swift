import SwiftUI

/// Search tab: browse the KES job board and practice for any listing.
struct SearchView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                JobSearchList(mode: .browse)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Search Jobs")
            .navigationDestination(for: Job.self) { JobDetailView(job: $0) }
        }
    }
}

struct JobDetailView: View {
    @Environment(AppModel.self) private var model
    let job: Job

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.title).font(.title2.bold())
                    Text(job.companyName ?? "Confidential").font(.headline).foregroundStyle(Theme.textSecondary)
                    FlowPills(job: job)
                }

                Button {
                    model.startBooking(with: JobDraft(job: job))
                } label: {
                    Label("Practice an Interview for This Job", systemImage: "phone.fill")
                }
                .buttonStyle(.primary)

                if let url = job.postingURL {
                    Link(destination: url) {
                        Label("View Full Posting", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                if let description = job.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About the role").font(.headline)
                        Text(JobLinkReader.clean(description))
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: 0xD1D5DB))
                            .textSelection(.enabled)
                    }
                    .card()
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FlowPills: View {
    let job: Job

    var body: some View {
        HStack(spacing: 6) {
            if let location = job.location { Pill(text: location, color: Theme.textSecondary) }
            if let salary = job.salaryText { Pill(text: salary, color: Theme.success) }
            if let category = job.categoryLabel { Pill(text: category, color: Theme.cyan) }
        }
    }
}
