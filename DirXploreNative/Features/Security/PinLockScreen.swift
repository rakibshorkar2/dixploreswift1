import SwiftUI

struct PinLockScreen: View {
    @Binding var isLocked: Bool
    @State private var pin = ""
    @State private var showError = false
    @State private var showForgotPin = false
    @State private var showSecurityQuestion = false
    @State private var securityAnswer = ""
    @State private var forgotPinError = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let pinLength = 6

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
                .overlay(.ultraThinMaterial)

            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accent)

                Text("DirXplore is Locked")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter your PIN to unlock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                pinDots

                if showError {
                    Text("Incorrect PIN")
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }

                Spacer()

                numberPad

                Button("Forgot PIN?") {
                    showForgotPin = true
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .alert("Forgot PIN", isPresented: $showForgotPin) {
            Button("Answer Security Question") { showSecurityQuestion = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can reset your PIN by answering your security question.")
        }
        .sheet(isPresented: $showSecurityQuestion) {
            securityQuestionView
        }
    }

    private var pinDots: some View {
        HStack(spacing: 16) {
            ForEach(0..<pinLength, id: \.self) { index in
                Circle()
                    .fill(index < pin.count ? Color.accent : Color.secondary.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .transition(.scale)
            }
        }
        .animation(.default, value: pin.count)
    }

    private var numberPad: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { row in
                HStack(spacing: 16) {
                    ForEach(1..<4) { col in
                        let number = row * 3 + col
                        numberButton(number)
                    }
                }
            }
            HStack(spacing: 16) {
                numberButton(nil)
                numberButton(0)
                backspaceButton
            }
        }
    }

    private func numberButton(_ number: Int?) -> some View {
        Button {
            if pin.count < pinLength {
                pin.append("\(number!)")
                if pin.count == pinLength {
                    verifyPin()
                }
            }
        } label: {
            Text(number.map { "\($0)" } ?? "")
                .font(.title)
                .fontWeight(.medium)
                .frame(width: 72, height: 72)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
        .disabled(number == nil)
    }

    private var backspaceButton: some View {
        Button {
            guard !pin.isEmpty else { return }
            pin.removeLast()
            showError = false
        } label: {
            Image(systemName: "delete.left")
                .font(.title)
                .frame(width: 72, height: 72)
        }
    }

    private func verifyPin() {
        guard SecurityManager.shared.verifyPin(pin) else {
            withAnimation {
                showError = true
                pin = ""
            }
            return
        }
        withAnimation {
            isLocked = false
            pin = ""
            showError = false
            SecurityManager.shared.unlock()
        }
    }

    private var securityQuestionView: some View {
        NavigationStack {
            Form {
                Section("Security Question") {
                    Text(SecurityManager.shared.securityQuestion ?? "No question set")
                }
                Section("Answer") {
                    SecureField("Enter your answer", text: $securityAnswer)
                }
                Section {
                    Button("Verify") {
                        guard SecurityManager.shared.verifySecurityAnswer(securityAnswer) else {
                            forgotPinError = true
                            return
                        }
                        isLocked = false
                    }
                    .disabled(securityAnswer.isEmpty)
                }
                if forgotPinError {
                    Section {
                        Text("Incorrect answer")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Reset PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct SecuritySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var showConfirm = false
    @State private var errorMessage: String?
    @State private var securityQuestion = ""
    @State private var securityAnswer = ""
    @State private var showSecuritySetup = false

    var body: some View {
        NavigationStack {
            Form {
                if !showSecuritySetup {
                    Section("Set PIN") {
                        SecureField("Enter PIN (4-6 digits)", text: $pin)
                            .keyboardType(.numberPad)
                        if showConfirm {
                            SecureField("Confirm PIN", text: $confirmPin)
                                .keyboardType(.numberPad)
                        }
                    }

                    Section {
                        Button(showConfirm ? "Save PIN" : "Continue") {
                            if !showConfirm {
                                guard pin.count >= 4 && pin.count <= 6 else {
                                    errorMessage = "PIN must be 4-6 digits"
                                    return
                                }
                                showConfirm = true
                                errorMessage = nil
                            } else {
                                guard pin == confirmPin else {
                                    errorMessage = "PINs do not match"
                                    return
                                }
                                SecurityManager.shared.setCustomPin(pin)
                                showSecuritySetup = true
                                errorMessage = nil
                            }
                        }
                        .disabled(pin.isEmpty)
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    Section("Security Question (For Recovery)") {
                        TextField("Enter a security question", text: $securityQuestion)
                        SecureField("Enter the answer", text: $securityAnswer)
                    }

                    Section {
                        Button("Save") {
                            SecurityManager.shared.setSecurity(question: securityQuestion, answer: securityAnswer)
                            dismiss()
                        }
                        .disabled(securityQuestion.isEmpty || securityAnswer.isEmpty)
                    }
                }
            }
            .navigationTitle("Security Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
