import SwiftUI
import UniformTypeIdentifiers

struct ProxyView: View {
    @State private var pm = ProxyManager.shared
    @State private var showAddSheet = false
    @State private var showBulkImport = false
    @State private var showYAMLImport = false
    @State private var showExport = false
    @State private var showBypass = false
    @State private var exportText = ""

    var body: some View {
        NavigationStack {
            Group {
                if pm.proxies.isEmpty {
                    ContentUnavailableView(
                        "No Proxies",
                        systemImage: "shield",
                        description: Text("Add a proxy to get started")
                    )
                } else {
                    List {
                        Section {
                            ForEach(pm.proxies) { proxy in
                                ProxyRow(proxy: proxy, onToggle: { toggleProxy(proxy) })
                                    .contextMenu {
                                        Button { testProxy(proxy) } label: { Label("Test Ping", systemImage: "antenna.radiowaves.left.and.right") }
                                        Button(role: .destructive) { pm.deleteProxy(id: proxy.id) } label: { Label("Delete", systemImage: "trash") }
                                    }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    pm.deleteProxy(id: pm.proxies[index].id)
                                }
                            }
                        }

                        if !pm.bypassList.isEmpty {
                            Section("Bypass List") {
                                ForEach(pm.bypassList, id: \.self) { domain in
                                    HStack {
                                        Text(domain).font(.caption)
                                        Spacer()
                                        Button { pm.removeBypass(domain) } label: {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).font(.caption)
                                        }
                                    }
                                }
                                Button { showBypass = true } label: {
                                    Label("Add Domain", systemImage: "plus").font(.caption)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Proxy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showAddSheet = true } label: { Label("Add Proxy", systemImage: "plus") }
                        Button { showBulkImport = true } label: { Label("Bulk Import", systemImage: "doc.text") }
                        Button { showYAMLImport = true } label: { Label("Import YAML", systemImage: "doc") }
                        if !pm.proxies.isEmpty {
                            Divider()
                            Button { exportProxies() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                            Button { showBypass = true } label: { Label("Bypass List", systemImage: "exclamationmark.triangle") }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) { AddProxySheet() }
            .sheet(isPresented: $showBulkImport) { BulkImportSheet() }
            .sheet(isPresented: $showYAMLImport) {
                DocumentPickerView(contentTypes: [.yaml]) { url in
                    pm.importFromYAML(url: url)
                }
            }
            .sheet(isPresented: $showExport) {
                NavigationStack {
                    VStack {
                        TextEditor(text: .constant(exportText))
                            .font(.caption)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                        Button("Copy to Clipboard") {
                            UIPasteboard.general.string = exportText
                            showExport = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .navigationTitle("Export Proxies")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { showExport = false } }
                    }
                }
            }
            .sheet(isPresented: $showBypass) {
                BypassListView()
            }
        }
    }

    private func exportProxies() {
        exportText = pm.proxies.map { proxy in
            var uri = "\(proxy.protocolType.rawValue)://\(proxy.host):\(proxy.port)"
            if !proxy.username.isEmpty {
                uri = "\(proxy.protocolType.rawValue)://\(proxy.username):\(proxy.password)@\(proxy.host):\(proxy.port)"
            }
            return uri
        }.joined(separator: "\n")
        showExport = true
    }

    private func toggleProxy(_ proxy: ProxyModel) {
        if proxy.isActive {
            pm.setActive(nil)
        } else {
            pm.setActive(proxy)
        }
    }

    private func testProxy(_ proxy: ProxyModel) {
        Task {
            await pm.testProxy(proxy)
        }
    }
}

struct ProxyRow: View {
    let proxy: ProxyModel
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: proxy.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(proxy.isActive ? .green : .secondary)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(proxy.protocolType.rawValue)://\(proxy.host):\(proxy.port)")
                    .font(.body)
                    .lineLimit(1)
                if let latency = proxy.latencyMs {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(latencyColor(latency))
                            .frame(width: 8, height: 8)
                        Text(String(format: "%.0f ms", latency))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if proxy.isActive {
                Text("Active")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private func latencyColor(_ ms: Double) -> Color {
        ms < 500 ? .green : ms < 1000 ? .orange : .red
    }
}

struct AddProxySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ProxyProtocol = .socks5
    @State private var host = ""
    @State private var port = "1080"
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Protocol") {
                    Picker("Type", selection: $selectedType) {
                        ForEach([ProxyProtocol.socks5, .socks4, .http, .https], id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Connection") {
                    TextField("Host", text: $host)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }

                Section("Authentication (Optional)") {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                }

                Section {
                    Button("Add Proxy") {
                        ProxyManager.shared.addProxy(
                            protocolType: selectedType,
                            host: host,
                            port: Int(port) ?? 1080,
                            username: username,
                            password: password
                        )
                        dismiss()
                    }
                    .disabled(host.isEmpty || port.isEmpty)
                }
            }
            .navigationTitle("Add Proxy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct BypassListView: View {
    @State private var pm = ProxyManager.shared
    @State private var newDomain = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Domain") {
                    HStack {
                        TextField("example.com", text: $newDomain)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Button("Add") {
                            pm.addBypass(newDomain.trimmingCharacters(in: .whitespacesAndNewlines))
                            newDomain = ""
                        }
                        .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section("Bypassed Domains") {
                    if pm.bypassList.isEmpty {
                        Text("No domains in bypass list")
                            .foregroundColor(.secondary)
                    }
                    ForEach(pm.bypassList, id: \.self) { domain in
                        HStack {
                            Text(domain).font(.body)
                            Spacer()
                            Button { pm.removeBypass(domain) } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bypass List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct BulkImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var uris = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Paste Proxy URIs") {
                    TextEditor(text: $uris)
                        .frame(minHeight: 200)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.caption)
                }
                Section {
                    Button("Import") {
                        let lines = uris.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        ProxyManager.shared.bulkImport(uris: lines)
                        dismiss()
                    }
                    .disabled(uris.isEmpty)
                }
            }
            .navigationTitle("Bulk Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
