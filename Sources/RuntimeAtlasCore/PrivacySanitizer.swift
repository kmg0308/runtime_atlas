import Foundation

public enum PrivacySanitizer {
    private static let sensitiveFragments = [
        "password", "passwd", "token", "secret", "api-key", "api_key", "apikey",
        "authorization", "cookie", "session"
    ]

    public static func text(_ value: String) -> String {
        sanitizeInline(value)
    }

    public static func containsSensitiveContent(_ value: String) -> Bool {
        sanitizeInline(value) != value
    }

    private static func sanitizeInline(_ value: String) -> String {
        var sanitized = value
        let patterns = [
            (#"(?i)\b(authorization|proxy-authorization|cookie|set-cookie|x-api-key)\s*:\s*.+$"#, "$1: <redacted>"),
            (#"[A-Za-z][A-Za-z0-9+.-]*://\S+"#, "<redacted-url>"),
            (#"(?i)\b(password|passwd|token|secret|api[-_]?key|authorization|cookie|session)\s*[:=]\s*\S+"#, "$1=<redacted>"),
            (#"(?i)\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]+"#, "$1 <redacted>")
        ]

        for (pattern, replacement) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: range,
                withTemplate: replacement
            )
        }
        return sanitized
    }
}
