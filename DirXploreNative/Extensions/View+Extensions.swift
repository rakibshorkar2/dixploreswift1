import SwiftUI

extension View {
    func glassBackground() -> some View {
        self.background(.ultraThinMaterial)
            .cornerRadius(12)
    }

    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    func hapticOnTap(_ feedback: HapticFeedbackStyle = .light) -> some View {
        self.onTapGesture {
            switch feedback {
            case .light: HapticFeedback.light()
            case .medium: HapticFeedback.medium()
            case .heavy: HapticFeedback.heavy()
            case .selection: HapticFeedback.selection()
            }
        }
    }
}

enum HapticFeedbackStyle {
    case light, medium, heavy, selection
}
