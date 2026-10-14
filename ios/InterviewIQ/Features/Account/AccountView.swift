import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(String(model.email.prefix(1)).uppercased())
                            .font(.title2.bold())
                            .frame(width: 52, height: 52)
                            .background(Theme.brandGradient, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.email).font(.body.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                            if let since = model.profile?.createdAt {
                                Text("Member since \(since.shortDisplay)")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    HStack(spacing: 8) {
                        if let profile = model.profile {
                            Pill(text: profile.planLabel, color: Theme.cyan)
                        }
                    }
                }

                Section {
                    Button {
                        model.startBooking()
                    } label: {
                        Label("Book an interview", systemImage: "phone.arrow.up.right")
                    }
                    Link(destination: AppConfig.supportURL) {
                        Label("Contact support", systemImage: "envelope")
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) { confirmSignOut = true }
                } footer: {
                    Text(appVersion).frame(maxWidth: .infinity).padding(.top, 12)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Account")
            .confirmationDialog("Sign out of InterviewIQ?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { Task { await model.signOut() } }
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "InterviewIQ \(version) (\(build))"
    }
}
