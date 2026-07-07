import SwiftUI

@Observable
@MainActor
final class AppTheme {
    static let shared = AppTheme()

    var colorScheme: ColorSchemeOption = .system
    var useAmoledBlack = false

    enum ColorSchemeOption: String, CaseIterable, Sendable {
        case system, light, dark

        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    var resolvedColorScheme: ColorScheme? {
        switch colorScheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var backgroundColor: Color {
        useAmoledBlack && resolvedColorScheme == .dark ? .amoledBlack : .appBackground
    }

    var surfaceColor: Color {
        useAmoledBlack && resolvedColorScheme == .dark ? .amoledSurface : .appSecondaryBackground
    }

    var groupedBackground: Color {
        useAmoledBlack && resolvedColorScheme == .dark ? .amoledBlack : .appGroupedBackground
    }

    func applyAmoledIfNeeded() {
        guard useAmoledBlack, colorScheme == .dark || (colorScheme == .system && UITraitCollection.current.userInterfaceStyle == .dark) else { return }
    }
}

private struct AppThemeKey: EnvironmentKey {
    @MainActor static let defaultValue = AppTheme.shared
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
