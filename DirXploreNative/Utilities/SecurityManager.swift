import Foundation
import LocalAuthentication
import CommonCrypto

enum LockType: String, Codable, Sendable {
    case none, device, custom
}

@Observable
@MainActor
final class SecurityManager {
    static let shared = SecurityManager()

    var lockType: LockType = .none
    var autoLockSeconds: TimeInterval = 0
    var isLocked = false
    var customPinHash: String?
    var securityQuestion: String?
    var securityAnswerHash: String?

    private let keychain = KeychainSwift()
    private var inactivityTimer: Timer?
    private var lastActivityDate = Date()

    private init() {
        loadSettings()
    }

    func loadSettings() {
        lockType = LockType(rawValue: UserDefaults.standard.string(forKey: "lockType") ?? "none") ?? .none
        autoLockSeconds = UserDefaults.standard.double(forKey: "autoLockSeconds")
        customPinHash = keychain.get("customPinHash")
        securityQuestion = UserDefaults.standard.string(forKey: "securityQuestion")
        securityAnswerHash = keychain.get("securityAnswerHash")
    }

    func saveLockType(_ type: LockType) {
        lockType = type
        UserDefaults.standard.set(type.rawValue, forKey: "lockType")
    }

    func saveAutoLock(_ seconds: TimeInterval) {
        autoLockSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: "autoLockSeconds")
    }

    func setCustomPin(_ pin: String) {
        customPinHash = pin.sha256()
        keychain.set(pin.sha256(), forKey: "customPinHash")
    }

    func setSecurity(question: String, answer: String) {
        securityQuestion = question
        securityAnswerHash = answer.sha256()
        UserDefaults.standard.set(question, forKey: "securityQuestion")
        keychain.set(answer.sha256(), forKey: "securityAnswerHash")
    }

    func verifyPin(_ pin: String) -> Bool {
        guard let hash = customPinHash else { return false }
        return pin.sha256() == hash
    }

    func verifySecurityAnswer(_ answer: String) -> Bool {
        guard let hash = securityAnswerHash else { return false }
        return answer.sha256() == hash
    }

    func authenticateDevice() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock DirXplore")
        } catch {
            return false
        }
    }

    func recordActivity() {
        lastActivityDate = Date()
        guard lockType != .none, autoLockSeconds > 0 else { return }
        resetInactivityTimer()
    }

    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: autoLockSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isLocked = true
            }
        }
    }

    func lock() {
        isLocked = true
    }

    func unlock() {
        isLocked = false
        recordActivity()
    }
}

private extension String {
    func sha256() -> String {
        guard let data = data(using: .utf8) else { return "" }
        let hash = data.withUnsafeBytes { bytes in
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
            return digest
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
