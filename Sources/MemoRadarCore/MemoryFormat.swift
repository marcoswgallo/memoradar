import Foundation

/// Sempre em português do Brasil, independente da região configurada no Mac.
public enum MemoryFormat {
    private static let gigabyte: Double = 1_073_741_824
    private static let megabyte: Double = 1_048_576

    public static func bytes(_ value: UInt64) -> String {
        let amount = Double(value)
        if amount >= gigabyte {
            return "\(oneDecimal(amount / gigabyte)) GB"
        }
        return "\(Int((amount / megabyte).rounded())) MB"
    }

    public static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 1 { return "menos de 1 min" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 48 { return "\(hours) h" }
        let days = oneDecimal(interval / 86400)
        return "\(days.hasSuffix(",0") ? String(days.dropLast(2)) : days) dias"
    }

    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
            .replacingOccurrences(of: ".", with: ",")
    }
}
