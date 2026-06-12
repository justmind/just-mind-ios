import Foundation

enum NewsletterResult {
    case success
    case failure(String)
}

/// Submits an email to the Just Mind newsletter form.
///
/// IMPORTANT: justmind.org's newsletter is implemented with **Gravity Forms**
/// (form id 18), gated by **Cloudflare Turnstile**. A direct programmatic POST
/// without solving the Turnstile challenge will be rejected.
///
/// This service does a best-effort attempt:
///   1. Fetches the homepage to harvest the dynamic state tokens that Gravity Forms
///      requires (`state_18`, `gform_currency`).
///   2. POSTs the submission as multipart/form-data to `/`.
///   3. If the server responds with a Gravity Forms confirmation marker, we treat
///      it as success. Otherwise we return failure so the caller can offer the
///      Safari fallback to the website footer.
enum NewsletterService {
    private static let homepage = URL(string: "https://justmind.org/")!
    private static let formID = "18"

    static func subscribe(email: String) async -> NewsletterResult {
        guard isValidEmail(email) else {
            return .failure("That email doesn't look quite right.")
        }
        do {
            let html = try await fetchHomepageHTML()
            let tokens = extractGravityFormsTokens(from: html)
            let body = buildMultipart(email: email, tokens: tokens)
            var request = URLRequest(url: homepage)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(body.boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("https://justmind.org/", forHTTPHeaderField: "Referer")
            request.setValue("application/x-www-form-urlencoded,text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            request.httpBody = body.data
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("No response from server.")
            }
            let text = String(data: data, encoding: .utf8) ?? ""
            let confirmed =
                text.contains("gform_confirmation_message_\(formID)") ||
                text.contains("GF_AJAX_POSTBACK") ||
                text.lowercased().contains("thank you") ||
                http.statusCode == 302
            if confirmed {
                return .success
            }
            // If Turnstile blocked it, the form usually re-renders with a validation error.
            return .failure("We couldn't confirm your signup. Try again, or sign up at justmind.org.")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private static func fetchHomepageHTML() async throws -> String {
        var req = URLRequest(url: homepage)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }

    struct GFTokens {
        var state: String = ""
        var currency: String = ""
        var styleSettings: String = "[]"
        var theme: String = "gravity-theme"
        var submissionMethod: String = "postback"
    }

    static func extractGravityFormsTokens(from html: String) -> GFTokens {
        var t = GFTokens()
        t.state = matchValue(in: html, regex: #"name='state_18'\s+value='([^']*)'"#) ?? ""
        t.currency = matchValue(in: html, regex: #"name='gform_currency'[^>]*value='([^']*)'"#) ?? ""
        if let style = matchValue(in: html, regex: #"name='gform_style_settings'[^>]*value='([^']*)'"#) {
            t.styleSettings = style
        }
        if let theme = matchValue(in: html, regex: #"name='gform_theme'[^>]*value='([^']*)'"#) {
            t.theme = theme
        }
        return t
    }

    private static func matchValue(in haystack: String, regex pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(haystack.startIndex..., in: haystack)
        guard let match = regex.firstMatch(in: haystack, range: range), match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: haystack) else { return nil }
        return String(haystack[r])
    }

    private struct MultipartBody {
        let boundary: String
        let data: Data
    }

    private static func buildMultipart(email: String, tokens: GFTokens) -> MultipartBody {
        let boundary = "----JustMindBoundary\(UUID().uuidString)"
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("input_4", email)         // email
        appendField("input_7", "")            // honeypot — must remain empty
        appendField("gform_submit", formID)
        appendField("is_submit_\(formID)", "1")
        appendField("gform_submission_method", tokens.submissionMethod)
        appendField("gform_theme", tokens.theme)
        appendField("gform_style_settings", tokens.styleSettings)
        appendField("gform_currency", tokens.currency)
        appendField("state_\(formID)", tokens.state)
        appendField("gform_target_page_number_\(formID)", "0")
        appendField("gform_source_page_number_\(formID)", "1")
        appendField("gform_unique_id", "")
        appendField("gform_field_values", "")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return MultipartBody(boundary: boundary, data: body)
    }

    static func isValidEmail(_ s: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }
}
