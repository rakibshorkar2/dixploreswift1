import SwiftUI

struct ProxyView: View {
    @StateObject private var viewModel = ProxyViewModel()

    var body: some View {
        NavigationView {
            Form {
                proxyConfigSection
                actionsSection
                statusSection
            }
            .navigationTitle("Proxy")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var proxyConfigSection: some View {
        Section("SOCKS5 Configuration") {
            Toggle("Enable Proxy", isOn: $viewModel.isEnabled)
                .onChange(of: viewModel.isEnabled) { _, newValue in
                    viewModel.toggleProxy(newValue)
                }

            HStack {
                Text("Host")
                Spacer()
                TextField("0.0.0.0", text: $viewModel.host)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Port")
                Spacer()
                TextField("1080", text: $viewModel.port)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Username")
                Spacer()
                TextField("username", text: $viewModel.username)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Password")
                Spacer()
                SecureField("••••••••", text: $viewModel.password)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            Button("Save Configuration") {
                viewModel.saveConfig()
            }
            .disabled(!viewModel.isEnabled)
        }
    }

    private var actionsSection: some View {
        Section("Connection Test") {
            Button(action: { viewModel.testPing() }) {
                HStack {
                    Text("Ping Test")
                    Spacer()
                    if viewModel.isTestingPing {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isTestingPing || viewModel.host.isEmpty)

            Button(action: { viewModel.testSOCKS5Connection() }) {
                Text("Test SOCKS5 Connection")
            }
            .disabled(viewModel.host.isEmpty || viewModel.port.isEmpty)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            if let ping = viewModel.pingResult {
                HStack {
                    Text("Ping")
                    Spacer()
                    Label(ping, systemImage: ping.contains("ms") ? "checkmark.circle" : "xmark.circle")
                        .foregroundColor(ping.contains("ms") ? .green : .red)
                }
            }

            if let testResult = viewModel.connectionTestResult {
                HStack {
                    Text("SOCKS5 Test")
                    Spacer()
                    Label(testResult, systemImage: testResult.contains("successful") ? "checkmark.circle" : "xmark.circle")
                        .foregroundColor(testResult.contains("successful") ? .green : .red)
                }
            }

            HStack {
                Text("Status")
                Spacer()
                Label(
                    viewModel.isEnabled ? "Active" : "Inactive",
                    systemImage: viewModel.isEnabled ? "shield.fill" : "shield.slash"
                )
                .foregroundColor(viewModel.isEnabled ? .green : .secondary)
            }

            HStack {
                Text("Default Proxy")
                Spacer()
                Text("103.166.253.92:1088")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
