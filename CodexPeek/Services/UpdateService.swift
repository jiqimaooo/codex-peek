import Foundation
import AppKit

@MainActor
class UpdateService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    enum UpdateState: Equatable {
        case idle
        case checking
        case updateAvailable(version: String, build: String)
        case noUpdateAvailable
        case downloading(progress: Double)
        case installing
        case error(String)
    }

    @Published var state: UpdateState = .idle
    private var session: URLSession?

    override init() {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }

    func checkForUpdates(silent: Bool = false) async {
        if !silent {
            state = .checking
        }

        let plistURL = URL(string: "https://raw.githubusercontent.com/jiqimaooo/codex-peek/main/CodexPeek/App/Info.plist")!
        // GitHub API: 获取 main 分支最新 commit 的 SHA，用 per_page=1 + Link header 中的 last page 来推算总 commit 数
        let commitsURL = URL(string: "https://api.github.com/repos/jiqimaooo/codex-peek/commits?sha=main&per_page=1")!

        do {
            // 1. 获取远程 Info.plist 中的版本号
            let (plistData, plistResponse) = try await URLSession.shared.data(from: plistURL)
            guard let plistHttp = plistResponse as? HTTPURLResponse, plistHttp.statusCode == 200 else {
                throw NSError(
                    domain: "UpdateService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to download remote Info.plist"]
                )
            }

            guard let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
                throw NSError(
                    domain: "UpdateService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to parse remote Info.plist"]
                )
            }

            let remoteVersion = plist["CFBundleShortVersionString"] as? String ?? "1.0.0"

            // 2. 获取远程 commit 总数作为构建号
            var commitRequest = URLRequest(url: commitsURL)
            commitRequest.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            let (_, commitsResponse) = try await URLSession.shared.data(for: commitRequest)

            var remoteBuild = "0"
            if let commitsHttp = commitsResponse as? HTTPURLResponse,
               let linkHeader = commitsHttp.value(forHTTPHeaderField: "Link") {
                // 解析 Link header 中 rel="last" 的 page 参数，即为总 commit 数
                if let lastMatch = linkHeader.range(of: #"page=(\d+)>; rel="last""#, options: .regularExpression) {
                    let matched = String(linkHeader[lastMatch])
                    if let numRange = matched.range(of: #"\d+"#, options: .regularExpression) {
                        remoteBuild = String(matched[numRange])
                    }
                }
            }

            let localVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
            let localBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

            let hasUpdate = isRemoteVersionNewer(
                remoteVersion: remoteVersion,
                remoteBuild: remoteBuild,
                localVersion: localVersion,
                localBuild: localBuild
            )

            if hasUpdate {
                state = .updateAvailable(version: remoteVersion, build: remoteBuild)
            } else {
                state = .noUpdateAvailable
            }
        } catch {
            if !silent {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func isRemoteVersionNewer(
        remoteVersion: String,
        remoteBuild: String,
        localVersion: String,
        localBuild: String
    ) -> Bool {
        let remoteComponents = remoteVersion.split(separator: ".").compactMap { Int($0) }
        let localComponents = localVersion.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(remoteComponents.count, localComponents.count)
        for i in 0..<maxLength {
            let remoteVal = i < remoteComponents.count ? remoteComponents[i] : 0
            let localVal = i < localComponents.count ? localComponents[i] : 0

            if remoteVal > localVal {
                return true
            } else if remoteVal < localVal {
                return false
            }
        }

        if let remoteB = Int(remoteBuild), let localB = Int(localBuild) {
            return remoteB > localB
        }

        return false
    }

    func startUpdate() {
        state = .downloading(progress: 0.0)
        
        let downloadURL = URL(string: "https://github.com/jiqimaooo/codex-peek/releases/download/latest/Codex.Peek.dmg")!
        let task = session?.downloadTask(with: downloadURL)
        task?.resume()
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.state = .downloading(progress: progress)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent("Codex.Peek.dmg")

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            Task { @MainActor in
                self.runUpdaterScript(dmgPath: destinationURL.path)
            }
        } catch {
            Task { @MainActor in
                self.state = .error("Failed to prepare updater: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            Task { @MainActor in
                self.state = .error(error.localizedDescription)
            }
        }
    }

    private func runUpdaterScript(dmgPath: String) {
        state = .installing

        let scriptContent = """
        #!/bin/bash
        PID=\(ProcessInfo.processInfo.processIdentifier)
        DMG_PATH="\(dmgPath)"
        APP_PATH="\(Bundle.main.bundlePath)"
        LOG_FILE="/tmp/codex_peek_update.log"

        echo "Starting update..." > "$LOG_FILE"
        echo "PID: $PID" >> "$LOG_FILE"
        echo "DMG_PATH: $DMG_PATH" >> "$LOG_FILE"
        echo "APP_PATH: $APP_PATH" >> "$LOG_FILE"

        while kill -0 $PID 2>/dev/null; do
            sleep 0.2
        done

        MOUNT_POINT="/tmp/codex_peek_mount"
        hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || true
        mkdir -p "$MOUNT_POINT"

        if ! hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -readonly -quiet; then
            echo "Failed to mount DMG" >> "$LOG_FILE"
            exit 1
        fi

        SRC_APP="$MOUNT_POINT/Codex Peek.app"
        if [ ! -d "$SRC_APP" ]; then
            echo "Codex Peek.app not found in DMG" >> "$LOG_FILE"
            hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || true
            exit 1
        fi

        rm -rf "$APP_PATH"
        cp -R "$SRC_APP" "$APP_PATH"
        hdiutil detach "$MOUNT_POINT" -force >> "$LOG_FILE" 2>&1
        rm -f "$DMG_PATH"

        open "$APP_PATH"
        rm -f "$0"
        """

        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("update_codex_peek.sh")

        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "nohup \(scriptURL.path) >/dev/null 2>&1 &"]
            try process.run()

            NSApp.terminate(nil)
        } catch {
            state = .error("Failed to run updater script: \(error.localizedDescription)")
        }
    }
}
