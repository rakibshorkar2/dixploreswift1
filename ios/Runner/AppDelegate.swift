import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var pendingFolderPickerResult: FlutterResult?

    private var rootViewController: UIViewController? {
        if let window = self.window { return window.rootViewController }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window.rootViewController
        }
        return nil
    }
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let downloadChannel = FlutterMethodChannel(
            name: "com.dirxplore/ios_download",
            binaryMessenger: controller.binaryMessenger
        )

        downloadChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            switch call.method {
            case "startDownload":
                if let args = call.arguments as? [String: Any],
                   let url = args["url"] as? String,
                   let fileName = args["fileName"] as? String,
                   let downloadId = args["downloadId"] as? String {
                    let saveDir = args["saveDir"] as? String
                    DownloadManager.shared.startDownload(url: url, fileName: fileName, downloadId: downloadId, saveDir: saveDir)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing parameters", details: nil))
                }

            case "pauseDownload":
                if let args = call.arguments as? [String: Any],
                   let downloadId = args["downloadId"] as? String {
                    DownloadManager.shared.pauseDownload(downloadId: downloadId)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing downloadId", details: nil))
                }

            case "cancelDownload":
                if let args = call.arguments as? [String: Any],
                   let downloadId = args["downloadId"] as? String {
                    DownloadManager.shared.cancelDownload(downloadId: downloadId)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing downloadId", details: nil))
                }

            case "cancelAll":
                DownloadManager.shared.cancelAll()
                result(true)

            case "getSavePath":
                if let persistentURL = DownloadManager.shared.persistentFolderURL {
                    result(persistentURL.path)
                    } else {
                        self.fallbackToDefaultSavePath(result)
                    }

            case "openFileLocation":
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    let fileURL = URL(fileURLWithPath: path)
                    DispatchQueue.main.async { [weak self] in
                        guard let rootVC = self?.rootViewController else { return }
                        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                        rootVC.present(activityVC, animated: true)
                    }
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil))
                }

            case "openURL":
                if let args = call.arguments as? [String: Any],
                   let urlStr = args["url"] as? String,
                   let url = URL(string: urlStr) {
                    DispatchQueue.main.async { [weak self] in
                        guard let rootVC = self?.rootViewController else { return }
                        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        rootVC.present(activityVC, animated: true)
                    }
                }
                result(nil)

            case "saveToFiles":
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    let fileURL = URL(fileURLWithPath: path)
                    DispatchQueue.main.async { [weak self] in
                        guard let rootVC = self?.rootViewController else { return }
                        let docPicker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
                        rootVC.present(docPicker, animated: true)
                    }
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil))
                }

            case "pickDownloadFolder":
                self.pendingFolderPickerResult = result
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    if let rootVC = self.rootViewController {
                        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
                        picker.delegate = self
                        rootVC.present(picker, animated: true)
                    } else {
                        self.pendingFolderPickerResult?(nil)
                        self.pendingFolderPickerResult = nil
                    }
                }

            case "getPersistentDownloadFolder":
                guard let bookmarkData = UserDefaults.standard.data(forKey: "persistentDownloadFolderBookmark") else {
                    result(nil)
                    return
                }
                var isStale = false
                do {
                    let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
                    if isStale {
                        let accessOK = url.startAccessingSecurityScopedResource()
                        defer { if accessOK { url.stopAccessingSecurityScopedResource() } }
                        let newBookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                        UserDefaults.standard.set(newBookmark, forKey: "persistentDownloadFolderBookmark")
                    }
                    result(url.path)
                } catch {
                    result(nil)
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let eventChannel = FlutterEventChannel(
            name: "com.dirxplore/ios_download_events",
            binaryMessenger: controller.binaryMessenger
        )
        eventChannel.setStreamHandler(DownloadManager.shared)

        let liveActivityChannel = FlutterMethodChannel(
            name: "com.dirxplore/live_activity",
            binaryMessenger: controller.binaryMessenger
        )

        liveActivityChannel.setMethodCallHandler { [weak self] (call, result) in
            guard self != nil else { return }
            switch call.method {
            case "isSupported":
                if #available(iOS 16.1, *) {
                    result(true)
                } else {
                    result(false)
                }

            case "enable":
                DownloadManager.shared.liveActivityEnabled = true
                result(true)

            case "disable":
                DownloadManager.shared.liveActivityEnabled = false
                DownloadManager.shared.endAllLiveActivities()
                result(true)

            case "isEnabled":
                result(DownloadManager.shared.liveActivityEnabled)

            case "start":
                if let args = call.arguments as? [String: Any],
                   let downloadId = args["downloadId"] as? String,
                   let fileName = args["fileName"] as? String {
                    DownloadManager.shared.startLiveActivity(downloadId: downloadId, fileName: fileName)
                }
                result(nil)

            case "update":
                if let args = call.arguments as? [String: Any],
                   let downloadId = args["downloadId"] as? String,
                   let received = args["received"] as? Int64,
                   let total = args["total"] as? Int64 {
                    DownloadManager.shared.updateLiveActivity(downloadId: downloadId, received: received, total: total)
                }
                result(nil)

            case "end":
                if let args = call.arguments as? [String: Any],
                   let downloadId = args["downloadId"] as? String,
                   let status = args["status"] as? String {
                    DownloadManager.shared.endLiveActivity(downloadId: downloadId, status: status)
                }
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let proxyChannel = FlutterMethodChannel(
            name: "com.dirxplore/proxy_config",
            binaryMessenger: controller.binaryMessenger
        )

        proxyChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "setProxy":
                if let args = call.arguments as? [String: Any] {
                    let host = args["host"] as? String ?? ""
                    let port = args["port"] as? Int ?? 0
                    let username = args["username"] as? String ?? ""
                    let password = args["password"] as? String ?? ""
                    let protocolStr = args["protocol"] as? String ?? "http"
                    let enabled = args["enabled"] as? Bool ?? false
                    DownloadManager.shared.setProxy(host: host, port: port, username: username, password: password, enabled: enabled, protocol: protocolStr)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let notificationChannel = FlutterMethodChannel(
            name: "com.dirxplore/notifications",
            binaryMessenger: controller.binaryMessenger
        )

        notificationChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "show":
                if let args = call.arguments as? [String: Any],
                   let title = args["title"] as? String,
                   let body = args["body"] as? String {
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = body
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }

    private func fallbackToDefaultSavePath(_ result: FlutterResult) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dirXploreDir = documentsDir.appendingPathComponent("DirXplore", isDirectory: true)
        try? FileManager.default.createDirectory(at: dirXploreDir, withIntermediateDirectories: true)
        result(dirXploreDir.path)
    }
}

extension AppDelegate: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            pendingFolderPickerResult?(nil)
            pendingFolderPickerResult = nil
            return
        }
        // Keep security-scoped access open for current session
        guard url.startAccessingSecurityScopedResource() else {
            pendingFolderPickerResult?(nil)
            pendingFolderPickerResult = nil
            return
        }
        DownloadManager.shared.persistentFolderURL = url
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "persistentDownloadFolderBookmark")
            pendingFolderPickerResult?(url.path)
        } catch {
            pendingFolderPickerResult?(nil)
        }
        pendingFolderPickerResult = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingFolderPickerResult?(nil)
        pendingFolderPickerResult = nil
    }
}
