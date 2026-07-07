import Foundation

extension Int64 {
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Int {
    var fileSizeFormatted: String {
        Int64(self).fileSizeFormatted
    }
}

extension Double {
    var speedFormatted: String {
        if self < 1024 { return "\(Int(self)) B/s" }
        if self < 1024 * 1024 { return String(format: "%.1f KB/s", self / 1024) }
        return String(format: "%.1f MB/s", self / (1024 * 1024))
    }

    var durationFormatted: String {
        guard self > 0, self < .greatestFiniteMagnitude else { return "--" }
        if self < 60 { return "\(Int(self))s" }
        if self < 3600 { return "\(Int(self / 60))m \(Int(self.truncatingRemainder(dividingBy: 60)))s" }
        let hours = Int(self / 3600)
        let mins = Int((self.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(mins)m"
    }
}
