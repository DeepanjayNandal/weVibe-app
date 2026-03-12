import Foundation

enum APIError: LocalizedError {
    case noProfile          // 404 — user has no profile yet
    case unauthorized       // 401
    case serverError(Int)   // any other non-2xx
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .noProfile:            return "No profile found."
        case .unauthorized:         return "Session expired. Please sign in again."
        case .serverError(let c):   return "Server error (\(c)). Please try again."
        case .network(let e):       return e.localizedDescription
        case .decoding(let e):      return "Response error: \(e.localizedDescription)"
        }
    }
}

struct APIClient {

    private let base = URL(string: AppConfig.apiBaseURL)!
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    // MARK: - Auth

    /// GET /users/me — returns true if profile is complete, throws .noProfile if 404.
    func checkProfile(token: String) async throws -> Bool {
        let req = request(path: "/users/me", method: "GET", token: token)
        let (_, response) = try await perform(req)
        let status = (response as! HTTPURLResponse).statusCode
        if status == 404 { throw APIError.noProfile }
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
        return true
    }

    /// POST /users/profile — submits onboarding data to create the user profile.
    func submitProfile(token: String, payload: UserProfilePayload) async throws {
        var req = request(path: "/users/profile", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await perform(req)
        let status = (response as! HTTPURLResponse).statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    // MARK: - Helpers

    private func request(path: String, method: String, token: String) -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func perform(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw APIError.network(error)
        }
    }
}

// MARK: - Profile Payload

struct UserProfilePayload: Encodable {
    // Step 1
    let dobDay: String
    let dobMonth: String
    let dobYear: String
    let sex: String
    let isSexHidden: Bool
    let ethnicities: [String]
    let locationCity: String
    let locationState: String
    let locationZip: String
    // Step 2
    let meetPreference: String
    let minAge: Int
    let maxAge: Int
    let distanceMiles: Int
    let relationshipGoals: [String]
    // Step 3
    let drinks: String
    let smoking: String
    let pets: String
    let children: String
    let workout: String
    let sleepSchedule: String
    // Step 4
    let education: String
    let career: String
    let heightFt: String
    let heightIn: String
    let heightCm: String
    let heightUnit: String
    let languages: [String]
    // Step 5
    let prompt1Question: String
    let prompt1Answer: String
    let prompt2Question: String
    let prompt2Answer: String
    let prompt3Question: String
    let prompt3Answer: String
    let ownPrompt: String
    let ownPromptAnswer: String

    init(from data: OnboardingData) {
        dobDay = data.dobDay
        dobMonth = data.dobMonth
        dobYear = data.dobYear
        sex = data.sex
        isSexHidden = data.isSexHidden
        ethnicities = Array(data.ethnicities)
        locationCity = data.locationCity
        locationState = data.locationState
        locationZip = data.locationZip
        meetPreference = data.meetPreference
        minAge = Int(data.minAge)
        maxAge = Int(data.maxAge)
        distanceMiles = Int(data.distance)
        relationshipGoals = Array(data.relationshipGoals)
        drinks = data.drinks
        smoking = data.smoking
        pets = data.pets
        children = data.children
        workout = data.workout
        sleepSchedule = data.sleepSchedule
        education = data.education
        career = data.career
        heightFt = data.heightFt
        heightIn = data.heightIn
        heightCm = data.heightCm
        heightUnit = data.heightUnit
        languages = Array(data.languages)
        prompt1Question = data.prompt1Question
        prompt1Answer = data.prompt1Answer
        prompt2Question = data.prompt2Question
        prompt2Answer = data.prompt2Answer
        prompt3Question = data.prompt3Question
        prompt3Answer = data.prompt3Answer
        ownPrompt = data.ownPrompt
        ownPromptAnswer = data.ownPromptAnswer
    }
}
