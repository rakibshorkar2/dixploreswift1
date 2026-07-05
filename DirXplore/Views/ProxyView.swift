import SwiftUI

struct ProxyView: View {
    @StateObject private var viewModel = ProxyViewModel()
    @State private var showSaveProfile = false
    @State private var newProfileName = ""
    @State private var showHistory = false
    @State private var showDeleteConfirm: ProxyProfile?

    var body: some View {
        NavigationView {
            Form {
                profilesSection
                proxyConfigSection
                actionsSection
                statusSection
            }
            .navigationTitle("Proxy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.copyConfigToClipboard()
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        Button(action: { showHistory.toggle() }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSaveProfile) {
                saveProfileView
            }
            .sheet(isPresented: $showHistory) {
                historyView
            }
            .alert("Delete Profile", isPresented: .init(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let p = showDeleteConfirm { viewModel.deleteProfile(p) }
                    showDeleteConfirm = nil
                }
                Button("Cancel", role: .cancel) { showDeleteConfirm = nil }
            } message: {
                Text("Delete profile \"\(showDeleteConfirm?.name ?? "")\"?")
            }
        }
    }

    private var profilesSection: some View {
        Section("Profiles") {
            if viewModel.profiles.isEmpty {
                Text("No saved profiles")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            ForEach(viewModel.profiles) { profile in
                HStack {
                    Button(action: { viewModel.loadProfile(profile) }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .foregroundColor(.primary)
                            Text(profile.displayString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if viewModel.selectedProfileID == profile.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = profile
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            Button(action: {
                newProfileName = ""
                showSaveProfile = true
            }) {
                Label("Save Current as Profile", systemImage: "plus.circle")
            }
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

    private var saveProfileView: some View {
        NavigationView {
            Form {
                TextField("Profile Name", text: $newProfileName)
                Button("Save") {
                    let name = newProfileName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        viewModel.saveAsProfile(name: name)
                    }
                    showSaveProfile = false
                }
                .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("Save Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showSaveProfile = false }
                }
            }
        }
    }

    private var historyView: some View {
        NavigationView {
            List {
                if viewModel.connectionHistory.isEmpty {
                    Text("No test history yet")
                        .foregroundColor(.secondary)
                }
                ForEach(viewModel.connectionHistory, id: \.self) { entry in
                    Text(entry)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Test History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showHistory = false }
                }
            }
        }
    }
}
