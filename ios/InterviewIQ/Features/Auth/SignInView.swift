import SwiftUI

/// Two-step sign-in: email, then the one-time code from the email.
struct SignInView: View {
    @Environment(AppModel.self) private var model

    private enum Step { case email, code }
    private enum Field { case email, code }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var resendAvailableAt = Date.distantPast
    @FocusState private var focus: Field?

    static let codeLength = 6

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                switch step {
                case .email: emailStep.transition(.move(edge: .leading).combined(with: .opacity))
                case .code: codeStep.transition(.move(edge: .trailing).combined(with: .opacity))
                }
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 72)
            .animation(.snappy, value: step)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .onAppear { focus = .email }
    }

    private var header: some View {
        VStack(spacing: 12) {
            BrandMark(size: 22)
            Text(step == .email ? "Member Portal" : "Check your email")
                .font(.largeTitle.bold())
            Text(step == .email
                 ? "Sign in with your email. We'll send you a code."
                 : "Enter the \(Self.codeLength)-digit code we sent to \(email).")
                .font(.callout)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var emailStep: some View {
        VStack(spacing: 14) {
            TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focus, equals: .email)
                .onSubmit(sendCode)
                .padding(16)
                .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(focus == .email ? Theme.cyan : Color(hex: 0x374151)))

            errorText

            Button(action: sendCode) {
                if isWorking { ProgressView().tint(.white) } else { Text("Send Code") }
            }
            .buttonStyle(.primary)
            .disabled(isWorking || !isValidEmail)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 14) {
            CodeField(code: $code, length: Self.codeLength)
                .focused($focus, equals: .code)
                .onChange(of: code) { _, newValue in
                    if newValue.count == Self.codeLength { verify() }
                }

            errorText

            Button(action: verify) {
                if isWorking { ProgressView().tint(.white) } else { Text("Sign In") }
            }
            .buttonStyle(.primary)
            .disabled(isWorking || code.count < Self.codeLength)

            HStack {
                Button("Use a different email") {
                    step = .email
                    code = ""
                    errorMessage = nil
                    focus = .email
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = Int(resendAvailableAt.timeIntervalSince(context.date).rounded(.up))
                    Button(remaining > 0 ? "Resend in \(remaining)s" : "Resend code", action: sendCode)
                        .disabled(remaining > 0 || isWorking)
                }
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 4)
        }
    }

    @ViewBuilder private var errorText: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Trouble signing in?")
                .foregroundStyle(Theme.textFaint)
            Link(AppConfig.supportEmail, destination: AppConfig.supportURL)
        }
        .font(.footnote)
    }

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    private func sendCode() {
        guard isValidEmail, !isWorking else { return }
        email = email.trimmingCharacters(in: .whitespaces).lowercased()
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await model.sendCode(to: email)
                resendAvailableAt = .now.addingTimeInterval(60)
                step = .code
                focus = .code
            } catch {
                errorMessage = "We couldn't send a code. Check the email address and try again."
            }
        }
    }

    private func verify() {
        guard code.count == Self.codeLength, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await model.verify(email: email, code: code)
                // AppModel switches to the signed-in UI via the auth state stream.
            } catch {
                errorMessage = "That code didn't work. Check it, or tap Resend for a new one."
                code = ""
            }
        }
    }
}

/// Six boxes backed by one hidden text field, so iOS can autofill the code from Mail.
private struct CodeField: View {
    @Binding var code: String
    let length: Int

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, minHeight: 58)
                .onChange(of: code) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(length))
                    if digits != newValue { code = digits }
                }
                .accessibilityLabel("Sign-in code")

            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { index in
                    let chars = Array(code)
                    let isActive = index == chars.count
                    Text(index < chars.count ? String(chars[index]) : "")
                        .font(.title.weight(.bold).monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isActive ? Theme.cyan : Color(hex: 0x374151), lineWidth: isActive ? 2 : 1))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
