import Foundation

struct LoginDetectionService {
    func isCodexLoggedIn() -> Bool {
        (try? AuthStore().loadCodexAuth())?.tokens != nil
    }
}
