import SwiftUI
import SwiftData

struct MyCareView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var context

    @State private var safariItem: SafariSheetItem?
    @State private var nameDraft: String = ""
    @State private var apptDraft: Date = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var hasAppt: Bool = false
    @State private var showClearConfirm: Bool = false
    @State private var biometricsUnavailable: String?

    private let portalURL = URL(string: "https://justmind.intakeq.com/portal")!
    private let privacyURL = URL(string: "https://justmind.org/privacy-policy/")!
    private let websiteURL = URL(string: "https://justmind.org/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: JMSpacing.xl) {
                    section(title: "Portal") {
                        portalCards
                    }
                    section(title: "Settings") {
                        settings
                    }
                    section(title: "About") {
                        aboutSection
                    }
                }
                .padding(.horizontal, JMSpacing.l)
                .padding(.vertical, JMSpacing.l)
            }
            .background(JMColor.background.ignoresSafeArea())
            .navigationTitle("My Care")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $safariItem) { SafariView(url: $0.url) }
            .alert("Clear all your data?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive, action: clearAll)
            } message: {
                Text("This will permanently delete all your journal entries and RŌS entries from this device. This cannot be undone.")
            }
            .onAppear(perform: hydrate)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: JMSpacing.m) {
            Text(title)
                .font(JMFont.footnote)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(1.5)
                .textCase(.uppercase)
            content()
        }
    }

    // MARK: Portal cards

    private var portalCards: some View {
        VStack(spacing: 0) {
            portalRow(icon: "message", title: "Message my therapist", subtitle: "Reach out between sessions")
            JMHairline()
            portalRow(icon: "doc.text", title: "Invoices & billing", subtitle: "Access your statements")
            JMHairline()
            portalRow(icon: "creditcard", title: "Payment method", subtitle: "Manage your card on file")
        }
        .jmQuietCardFlush()
    }

    private func portalRow(icon: String, title: String, subtitle: String) -> some View {
        Button {
            // Only fire success haptic for the messaging action, per spec.
            if title.lowercased().contains("message") {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            safariItem = SafariSheetItem(url: portalURL)
        } label: {
            HStack(spacing: JMSpacing.l) {
                // Icon foreground neutralized — green is reserved for primary CTAs.
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(JMColor.textSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(JMFont.body)
                        .foregroundStyle(JMColor.textPrimary)
                    Text(subtitle)
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(JMColor.textSecondary.opacity(0.7))
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.cardV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings

    private var settings: some View {
        VStack(spacing: JMSpacing.m) {
            // Preferred name
            VStack(alignment: .leading, spacing: 6) {
                Text("Preferred name")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(1)
                    .textCase(.uppercase)
                TextField("First name", text: $nameDraft)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .font(JMFont.body)
                    .padding(.vertical, 10)
                    .onChange(of: nameDraft) { _, new in
                        prefs.preferredName = new.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                JMHairline()
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .jmQuietCardFlush()

            // Next appointment
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next appointment")
                            .font(JMFont.body)
                            .foregroundStyle(JMColor.textPrimary)
                        Text("Used for the home reminder")
                            .font(JMFont.caption)
                            .foregroundStyle(JMColor.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $hasAppt.animation())
                        .labelsHidden()
                        .tint(JMColor.primary)
                        .onChange(of: hasAppt) { _, new in
                            prefs.nextAppointment = new ? apptDraft : nil
                        }
                }
                .padding(.horizontal, JMSpacing.l)
                .padding(.vertical, JMSpacing.l)
                if hasAppt {
                    JMHairline()
                    DatePicker("Date", selection: $apptDraft, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .padding(.horizontal, JMSpacing.l)
                        .padding(.vertical, JMSpacing.m)
                        .onChange(of: apptDraft) { _, new in
                            prefs.nextAppointment = new
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .jmQuietCardFlush()

            // App lock
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock the app")
                            .font(JMFont.body)
                            .foregroundStyle(JMColor.textPrimary)
                        Text("Require Face ID, Touch ID, or your passcode each time you open Just Mind.")
                            .font(JMFont.caption)
                            .foregroundStyle(JMColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { prefs.appLockEnabled },
                        set: { newValue in
                            if newValue {
                                Task {
                                    let result = await BiometricsService.authenticate(reason: "Enable app lock for Just Mind")
                                    switch result {
                                    case .success:
                                        prefs.appLockEnabled = true
                                        biometricsUnavailable = nil
                                    case .unavailable(let m):
                                        biometricsUnavailable = m
                                    case .failure, .cancelled:
                                        prefs.appLockEnabled = false
                                    }
                                }
                            } else {
                                prefs.appLockEnabled = false
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(JMColor.primary)
                }
                .padding(.horizontal, JMSpacing.l)
                .padding(.vertical, JMSpacing.l)
                if let m = biometricsUnavailable {
                    JMHairline()
                    Text(m)
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.warning)
                        .padding(.horizontal, JMSpacing.l)
                        .padding(.vertical, JMSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .jmQuietCardFlush()

            // Clear data
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .light))
                    Text("Clear all my data")
                        .font(JMFont.body)
                }
                .foregroundStyle(JMColor.warning)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: JMRadius.button, style: .continuous)
                        .strokeBorder(JMColor.warning.opacity(0.4), lineWidth: JMHairline.width)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: About

    private var aboutSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("App version")
                    .font(JMFont.body)
                    .foregroundStyle(JMColor.textPrimary)
                Spacer()
                Text(appVersion)
                    .font(JMFont.body)
                    .foregroundStyle(JMColor.textSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.m)

            JMHairline()

            aboutLink("Privacy Policy", url: privacyURL)
            JMHairline()
            aboutLink("justmind.org", url: websiteURL)

            VStack(alignment: .leading, spacing: 0) {
                JMHairline()
                Text("All your data is stored only on this device and is never shared with Just Mind Counseling or any third party.")
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.textSecondary)
                    .lineSpacing(2)
                    .padding(.horizontal, JMSpacing.l)
                    .padding(.vertical, JMSpacing.l)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCardFlush()
    }

    private func aboutLink(_ title: String, url: URL) -> some View {
        Button {
            safariItem = SafariSheetItem(url: url)
        } label: {
            HStack {
                Text(title).foregroundStyle(JMColor.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(JMColor.textSecondary.opacity(0.7))
            }
            .font(JMFont.body)
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func hydrate() {
        nameDraft = prefs.preferredName
        if let d = prefs.nextAppointment {
            hasAppt = true
            apptDraft = d
        } else {
            hasAppt = false
        }
    }

    private func clearAll() {
        do {
            try context.delete(model: MoodEntry.self)
            try context.delete(model: ROSEntry.self)
            try context.delete(model: CachedPost.self)
            try context.save()
        } catch {
            // Best effort.
        }
        prefs.resetAll()
    }
}
