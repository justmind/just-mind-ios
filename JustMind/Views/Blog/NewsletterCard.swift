import SwiftUI

struct NewsletterCard: View {
    @Environment(AppPreferences.self) private var prefs
    @State private var email: String = ""
    @State private var status: Status = .idle
    @State private var safariFallback: SafariSheetItem?
    @FocusState private var emailFocused: Bool

    enum Status { case idle, sending, success, failure(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text("Get mental health insights delivered to your inbox.")
                .font(JMFont.bodyEmph)
                .foregroundStyle(JMColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if prefs.newsletterSubscribed {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(JMColor.success)
                    Text("You're signed up. Check your inbox to confirm.")
                        .font(JMFont.callout)
                        .foregroundStyle(JMColor.textSecondary)
                }
            } else {
                HStack(spacing: 8) {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .focused($emailFocused)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(JMColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: JMRadius.button, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: JMRadius.button, style: .continuous)
                                .strokeBorder(JMColor.divider, lineWidth: 1)
                        )

                    Button {
                        Task { await submit() }
                    } label: {
                        if case .sending = status {
                            ProgressView().tint(.white)
                                .frame(width: 80)
                        } else {
                            Text("Subscribe").frame(width: 80)
                        }
                    }
                    .buttonStyle(.jmPrimary)
                    .frame(width: 110)
                    .disabled(disableSubmit)
                }
                statusLine
            }
        }
        .padding(JMSpacing.l)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
        )
        .padding(.horizontal, JMSpacing.l)
        .padding(.bottom, JMSpacing.s)
        .sheet(item: $safariFallback) { SafariView(url: $0.url) }
    }

    private var disableSubmit: Bool {
        if case .sending = status { return true }
        return !NewsletterService.isValidEmail(email)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .idle, .sending:
            EmptyView()
        case .success:
            Text("You're signed up! Check your inbox to confirm.")
                .font(JMFont.caption)
                .foregroundStyle(JMColor.success)
        case .failure(let msg):
            HStack(spacing: 6) {
                Text(msg)
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.warning)
                Spacer(minLength: 4)
                Button("Sign up at justmind.org") {
                    safariFallback = SafariSheetItem(
                        url: URL(string: "https://justmind.org/#newsletter")!
                    )
                }
                .font(JMFont.caption)
                .foregroundStyle(JMColor.primary)
            }
        }
    }

    private func submit() async {
        emailFocused = false
        status = .sending
        let result = await NewsletterService.subscribe(email: email)
        switch result {
        case .success:
            status = .success
            prefs.newsletterSubscribed = true
            email = ""
        case .failure(let m):
            status = .failure(m)
        }
    }
}
