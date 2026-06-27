import Foundation

protocol CodexUsageProvider {
    var sourceName: String { get }
    func fetchUsage() async throws -> CodexUsage
}

struct CodexUsageProviderChain: CodexUsageProvider {
    let sourceName = "Provider Chain"

    private let providers: [CodexUsageProvider]

    init(providers: [CodexUsageProvider] = [
        OAuthCodexProvider(),
        CLIRPCProvider()
    ]) {
        self.providers = providers
    }

    func fetchUsage() async throws -> CodexUsage {
        var failures: [String] = []

        for provider in providers {
            do {
                return try await provider.fetchUsage()
            } catch let error as UsageError {
                failures.append("\(provider.sourceName): \(error.localizedDescription)")
            } catch {
                failures.append("\(provider.sourceName): \(error.localizedDescription)")
            }
        }

        throw UsageError.allProvidersFailed(failures)
    }
}
