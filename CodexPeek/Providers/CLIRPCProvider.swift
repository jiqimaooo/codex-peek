import Foundation

struct CLIRPCProvider: CodexUsageProvider {
    let sourceName = "Codex CLI RPC"

    func fetchUsage() async throws -> CodexUsage {
        guard await isCodexCLIAvailable() else {
            throw UsageError.providerUnavailable("未找到 codex 命令，或 Codex CLI 不在 PATH 中。")
        }

        throw UsageError.providerUnavailable("当前版本暂未发现稳定公开的 Codex CLI usage RPC，请使用 Codex CLI 登录后通过 OAuth 用量接口读取。")
    }

    private func isCodexCLIAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["codex", "--version"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
