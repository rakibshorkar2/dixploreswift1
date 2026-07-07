import SwiftUI

struct HashVerificationView: View {
    let fileURL: URL
    let fileName: String
    @State private var md5Hash: String?
    @State private var sha256Hash: String?
    @State private var isComputing = true

    var body: some View {
        NavigationStack {
            List {
                Section("File") {
                    LabeledContent("Name", value: fileName)
                }
                Section("MD5") {
                    if let md5 = md5Hash {
                        Text(md5)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    } else {
                        Text("Computing...")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("SHA-256") {
                    if let sha = sha256Hash {
                        Text(sha)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    } else {
                        Text("Computing...")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("File Hash")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await computeHashes()
            }
        }
    }

    private func computeHashes() async {
        let service = FileHashService.shared
        async let md5 = service.md5(url: fileURL)
        async let sha256 = service.sha256(url: fileURL)
        (md5Hash, sha256Hash) = await (md5, sha256)
        isComputing = false
    }
}
