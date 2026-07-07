import SwiftUI
import UniformTypeIdentifiers
import WebKit
import QuickLook

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?

    init(activityItems: [Any], applicationActivities: [UIActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        return WKWebView(frame: .zero, configuration: config)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

struct DragDropDelegate: ViewModifier {
    let item: URL

    func body(content: Content) -> some View {
        content.onDrag { NSItemProvider(object: item.lastPathComponent as NSString) }
    }
}

extension View {
    func dragFile(_ url: URL) -> some View {
        modifier(DragDropDelegate(item: url))
    }

    func onDropFile(isTargeted: Binding<Bool>, _ action: @escaping (URL) -> Void) -> some View {
        self.onDrop(of: [.fileURL], isTargeted: isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in action(url) }
            }
            return true
        }
    }
}

extension Color {
    static var random: Color {
        Color(
            red: Double.random(in: 0.3...0.9),
            green: Double.random(in: 0.3...0.9),
            blue: Double.random(in: 0.3...0.9)
        )
    }
}

extension UIDevice {
    var totalDiskSpace: Int64 {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return (attributes?[.systemSize] as? NSNumber)?.int64Value ?? 0
    }

    var freeDiskSpace: Int64 {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return (attributes?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }
}
