import Foundation
import SwiftUI

extension Color {
    static let appBackground = Color(.systemBackground)
    static let appSecondaryBackground = Color(.secondarySystemBackground)
    static let appAccent = Color.blue
}

extension View {
    func standardPadding() -> some View {
        self.padding(.horizontal, 16).padding(.vertical, 8)
    }
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension URL {
    var fileNameWithoutExtension: String {
        deletingPathExtension().lastPathComponent
    }
}
