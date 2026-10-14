import SwiftUI

/// Search box, category filters and results from the KES job board.
/// Used by the Search tab (`.browse`) and the booking screen (`.picker`). The caller provides the scroll view.
struct JobSearchList: View {
    enum Mode { case browse, picker }

    let mode: Mode
    var onSelect: (Job) -> Void = { _ in }

    @State private var text = ""
    @State private var category: String?
    @State private var jobs: [Job] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField
            categoryChips
            results
        }
        .task { if jobs.isEmpty { await load(reset: true) } }
        .onChange(of: text) { _, _ in debounceSearch() }
        .onChange(of: category) { _, _ in Task { await load(reset: true) } }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
            TextField("Search jobs, skills or companies", text: $text)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { Task { await load(reset: true) } }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .fieldStyle()
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", value: nil)
                ForEach(Job.categories, id: \.value) { chip(label: $0.label, value: $0.value) }
            }
        }
    }

    private func chip(label: String, value: String?) -> some View {
        let isOn = category == value
        return Button(label) { category = value }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isOn ? .white : Theme.textSecondary)
            .background(isOn ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.cardRaised), in: Capsule())
            .sensoryFeedback(.selection, trigger: isOn)
    }

    @ViewBuilder private var results: some View {
        if let errorMessage {
            EmptyStateView(symbol: "wifi.exclamationmark", title: "Couldn't load jobs", message: errorMessage)
        } else if jobs.isEmpty && isLoading {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
        } else if jobs.isEmpty {
            EmptyStateView(symbol: "magnifyingglass",
                           title: "No matching jobs",
                           message: "Try a different search or category.")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(jobs) { job in
                    switch mode {
                    case .browse:
                        NavigationLink(value: job) { JobRow(job: job, showsChevron: true) }
                            .buttonStyle(.plain)
                    case .picker:
                        Button { onSelect(job) } label: { JobRow(job: job, actionLabel: "Select") }
                            .buttonStyle(.plain)
                    }
                }
                if hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .task { await load(reset: false) }
                }
            }
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await load(reset: true)
        }
    }

    private func load(reset: Bool) async {
        if isLoading && !reset { return }
        isLoading = true
        defer { isLoading = false }
        let nextPage = reset ? 0 : page + 1
        let query = text
        let filter = category
        do {
            let batch = try await JobService.search(text: query, category: filter, page: nextPage)
            // Drop results for a search the user has already changed.
            guard query == text, filter == category else { return }
            jobs = reset ? batch : jobs + batch
            page = nextPage
            hasMore = batch.count == JobService.pageSize
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            if reset { jobs = [] }
            hasMore = false
            errorMessage = "Check your connection and try again."
        }
    }
}

struct JobRow: View {
    let job: Job
    var showsChevron = false
    var actionLabel: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.brandGradient)
                .frame(width: 40, height: 40)
                .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(job.title).font(.body.weight(.semibold)).lineLimit(2)
                Text([job.companyName ?? "Confidential", job.location].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let salary = job.salaryText { Pill(text: salary, color: Theme.success) }
                    if let category = job.categoryLabel { Pill(text: category, color: Theme.cyan) }
                }
            }
            Spacer(minLength: 0)
            if let actionLabel {
                Text(actionLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.cyan)
            } else if showsChevron {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textFaint)
            }
        }
        .card(padding: 14)
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch job.category {
        case "warehouse": "shippingbox.fill"
        case "manufacturing": "gearshape.2.fill"
        case "logistics": "truck.box.fill"
        case "skilled_trades": "wrench.and.screwdriver.fill"
        case "engineering": "cpu.fill"
        case "supervision": "person.3.fill"
        default: "briefcase.fill"
        }
    }
}
