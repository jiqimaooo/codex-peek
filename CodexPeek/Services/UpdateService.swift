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

    struct RemoteVersionInfo: Decodable {
        let version: String
        let build: String
    }

    func checkForUpdates(silent: Bool = false) async {
        if !silent {
            state = .checking
        }

        let versionURL = URL(string: "https://github.com/jiqimaooo/codex-peek/releases/download/latest/version.json")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: versionURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(
                    domain: "UpdateService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to download remote version.json (Status \((response as? HTTPURLResponse)?.statusCode ?? 0))"]
                )
            }

            let remoteInfo = try JSONDecoder().decode(RemoteVersionInfo.self, from: data)

            let localVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
            let localBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

            let hasUpdate = isRemoteVersionNewer(
                remoteVersion: remoteInfo.version,
                remoteBuild: remoteInfo.build,
                localVersion: localVersion,
                localBuild: localBuild
            )

            if hasUpdate {
                state = .updateAvailable(version: remoteInfo.version, build: remoteInfo.build)
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
