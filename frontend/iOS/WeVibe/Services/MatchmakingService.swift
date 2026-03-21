import Foundation

final class MatchmakingService {
    
    func findMatch() async throws -> String {
        try await Task.sleep(for: .seconds(5))
        return "mock-match-id-\(UUID().uuidString.prefix(8))"
    }
    
    enum MatchmakingError: LocalizedError {
        case serverError
        case timeout
        case noMatchFound
     
        var errorDescription: String? {
            switch self {
            case .serverError:   return "Something went wrong. Please try again."
            case .timeout:       return "Taking longer than usual. Hang tight..."
            case .noMatchFound:  return "No match found right now. Try again soon!"
            }
        }
    }
}

private struct MatchResult: Decodable {
    let matchId: String
}
 
