import SwiftUI

/// Request to open the booking screen, optionally pre-filled with a job.
struct BookingRequest: Identifiable {
    let id = UUID()
    var draft: JobDraft?
}

/// Set up a mock interview call: pick a role (job board, typed details, or a pasted link),
/// confirm the phone number, then call now or schedule for later.
struct BookInterviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum Source: String, CaseIterable, Identifiable {
        case board = "Job Board", details = "Enter Details", link = "Paste Link"
        var id: Self { self }
    }

    private enum Outcome: Equatable {
        case calling
        case scheduled(Date)
    }

    @State private var source: Source
    @State private var draft: JobDraft
    @State private var selectedJob: Job?
    @State private var phone = ""
    @State private var linkText = ""
    @State private var isReadingLink = false
    @State private var linkMessage: String?
    @State private var showScheduler = false
    @State private var scheduleDate = Date.now.addingTimeInterval(60 * 60)
    @State private var isBooking = false
    @State private var errorMessage: String?
    @State private var outcome: Outcome?

    init(initialDraft: JobDraft? = nil) {
        _draft = State(initialValue: initialDraft ?? JobDraft())
        _source = State(initialValue: initialDraft == nil ? .board : .details)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let outcome {
                    confirmation(outcome)
                } else {
                    form
                }
            }
            .screenBackground()
            .navigationTitle(outcome == nil ? "Book an Interview" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(outcome == nil ? "Cancel" : "Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showScheduler) { scheduler }
            .sensoryFeedback(.success, trigger: outcome)
            .onAppear {
                if phone.isEmpty, let saved = model.profile?.phone {
                    phone = PhoneNumber.e164(from: saved).map(PhoneNumber.display) ?? saved
                }
            }
        }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.profile?.canBookInterviews == false { membershipNotice }

                stepHeader(1, "Choose the job")
                Picker("Source", selection: $source) {
                    ForEach(Source.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch source {
                case .board: boardSection
                case .details: detailsSection
                case .link: linkSection
                }

                stepHeader(2, "Where should we call you?")
                phoneField

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }

                actions
            }
            .padding()
            .animation(.snappy, value: source)
            .animation(.snappy, value: selectedJob)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func stepHeader(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.footnote.bold())
                .frame(width: 24, height: 24)
                .background(Theme.brandGradient, in: Circle())
            Text(title).font(.headline)
        }
    }

    private var membershipNotice: some View {
        Label {
            Text("Booking mock interviews needs an active Unlimited Monthly membership.")
        } icon: {
            Image(systemName: "lock.fill")
        }
        .font(.footnote)
        .foregroundStyle(Theme.warning)
        .card(padding: 14)
    }

    // Job Board

    @ViewBuilder private var boardSection: some View {
        if let job = selectedJob {
            VStack(alignment: .leading, spacing: 12) {
                JobRow(job: job)
                Button("Choose a different job") {
                    selectedJob = nil
                    draft = JobDraft()
                }
                .font(.subheadline.weight(.semibold))
            }
        } else {
            JobSearchList(mode: .picker) { job in
                selectedJob = job
                draft = JobDraft(job: job)
            }
            .frame(minHeight: 360)
        }
    }

    // Enter Details

    private var detailsSection: some View {
        VStack(spacing: 12) {
            LabeledField(title: "Job title", isRequired: true) {
                TextField("e.g. Forklift Operator", text: $draft.title)
                    .textInputAutocapitalization(.words)
            }
            LabeledField(title: "Company") {
                TextField("Optional", text: $draft.company)
                    .textInputAutocapitalization(.words)
            }
            LabeledField(title: "Job description") {
                TextField("Paste the description or key requirements (optional)", text: $draft.description, axis: .vertical)
                    .lineLimit(4...10)
            }
        }
    }

    // Paste Link

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("https://…", text: $linkText)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(readLink)
                    .fieldStyle()
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    linkText = text
                    readLink()
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(Theme.cyan)
            }
            if isReadingLink {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Reading the job posting…").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            } else if let linkMessage {
                Text(linkMessage).font(.footnote).foregroundStyle(Theme.textSecondary)
            } else if draft.link.isEmpty {
                Button("Get job details", action: readLink)
                    .font(.subheadline.weight(.semibold))
                    .disabled(JobLinkReader.normalizedURL(linkText) == nil)
            }
            if !draft.link.isEmpty || linkMessage != nil {
                detailsSection
            }
        }
    }

    private func readLink() {
        guard !isReadingLink else { return }
        guard JobLinkReader.normalizedURL(linkText) != nil else {
            linkMessage = JobLinkReader.ReadError.invalidLink.errorDescription
            return
        }
        isReadingLink = true
        linkMessage = nil
        Task {
            defer { isReadingLink = false }
            do {
                draft = try await JobLinkReader.read(linkText)
                linkMessage = "Got it. Check the details below."
            } catch {
                draft = JobDraft()
                draft.link = JobLinkReader.normalizedURL(linkText)?.absoluteString ?? linkText
                linkMessage = JobLinkReader.ReadError.nothingFound.errorDescription
            }
        }
    }

    // Phone

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("(555) 123-4567", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .fieldStyle()
            Text(phone.isEmpty || normalizedPhone != nil
                 ? "Our AI interviewer will call this number."
                 : "Enter a 10-digit US number, or include the country code (e.g. +44…).")
                .font(.caption)
                .foregroundStyle(phone.isEmpty || normalizedPhone != nil ? Theme.textMuted : Theme.warning)
        }
    }

    private var normalizedPhone: String? { PhoneNumber.e164(from: phone) }

    // Actions

    private var canSubmit: Bool {
        draft.isComplete && normalizedPhone != nil && !isBooking && model.profile?.canBookInterviews != false
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                book(at: nil)
            } label: {
                if isBooking && !showScheduler {
                    ProgressView().tint(.white)
                } else {
                    Label("Call Me Now", systemImage: "phone.fill")
                }
            }
            .buttonStyle(.primary)

            Button {
                showScheduler = true
            } label: {
                Label("Schedule for Later", systemImage: "calendar")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .disabled(!canSubmit)
        .padding(.top, 4)
    }

    private var scheduler: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Interview time",
                           selection: $scheduleDate,
                           in: Date.now.addingTimeInterval(5 * 60)...,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                Text("We'll call \(normalizedPhone.map(PhoneNumber.display) ?? phone) at this time (\(TimeZone.current.localizedName(for: .standard, locale: .current) ?? TimeZone.current.identifier)).")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    book(at: scheduleDate)
                } label: {
                    if isBooking { ProgressView().tint(.white) } else { Text("Confirm Interview") }
                }
                .buttonStyle(.primary)
                .disabled(isBooking)
                Spacer()
            }
            .padding()
            .screenBackground()
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showScheduler = false } }
            }
        }
        .presentationDetents([.large])
    }

    private func book(at date: Date?) {
        guard let e164 = normalizedPhone, draft.isComplete else { return }
        isBooking = true
        errorMessage = nil
        Task {
            defer { isBooking = false }
            do {
                if PhoneNumber.e164(from: model.profile?.phone ?? "") != e164 {
                    try await BookingService.savePhone(e164)
                }
                try await BookingService.book(draft, at: date)
                showScheduler = false
                outcome = date.map(Outcome.scheduled) ?? .calling
                await model.refresh()
            } catch {
                showScheduler = false
                errorMessage = "We couldn't book that interview. \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Confirmation

    private func confirmation(_ outcome: Outcome) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: outcome == .calling ? "phone.arrow.down.left.fill" : "calendar.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(Theme.brandGradient)
                .symbolEffect(.pulse, isActive: outcome == .calling)
            switch outcome {
            case .calling:
                Text("Calling you now").font(.title2.bold())
                Text("Keep your phone nearby. Your AI interviewer will call \(normalizedPhone.map(PhoneNumber.display) ?? phone) within about a minute.")
            case .scheduled(let date):
                Text("Interview scheduled").font(.title2.bold())
                Text("We'll call \(normalizedPhone.map(PhoneNumber.display) ?? phone) on \(date.formatted(date: .complete, time: .shortened)).")
            }
            Text("Role: \(draft.title)\(draft.company.isEmpty ? "" : " at \(draft.company)")")
                .foregroundStyle(Theme.textMuted)
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(.primary)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.textSecondary)
        .multilineTextAlignment(.center)
        .padding(24)
    }
}

// MARK: - Small shared pieces

struct LabeledField<Content: View>: View {
    let title: String
    var isRequired = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(title)
                if isRequired { Text("*").foregroundStyle(Theme.cyan) }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
            content.fieldStyle()
        }
    }
}

extension View {
    /// Dark rounded input field matching the sign-in screen.
    func fieldStyle() -> some View {
        padding(14)
            .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(hex: 0x374151)))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.cyan)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.cyan.opacity(configuration.isPressed ? 0.2 : 0.12),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.cyan.opacity(0.5)))
            .opacity(isEnabled ? 1 : 0.5)
    }
}
