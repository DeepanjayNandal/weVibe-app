import Foundation

private struct ErrorResponse: Decodable {
    struct ErrorBody: Decodable { let code: String }
    let error: ErrorBody
}

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

    /// GET /users/profile — returns true if profile exists, throws .noProfile if not yet created.
    func checkProfile(token: String) async throws -> Bool {
        let req = request(path: "/users/profile", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = (response as! HTTPURLResponse).statusCode
        if status == 200 { return true }
        if status == 401 {
            // PROFILE_NOT_FOUND means user exists but has no profile yet → send to onboarding
            if let body = try? JSONDecoder().decode(ErrorResponse.self, from: data),
               body.error.code == "PROFILE_NOT_FOUND" {
                throw APIError.noProfile
            }
            throw APIError.unauthorized
        }
        throw APIError.serverError(status)
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

    /// POST /auth/login — creates or finds the backend user record for SSO and email login.
    func loginUser(idToken: String, provider: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("/auth/login"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["provider": provider, "idToken": idToken]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(req)
        let status = (response as! HTTPURLResponse).statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    /// POST /auth/register — creates the backend user record after Firebase registration.
    /// Silently ignores 409 (already registered — safe to retry).
    func registerUser(idToken: String, provider: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("/auth/register"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["provider": provider, "idToken": idToken]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(req)
        let status = (response as! HTTPURLResponse).statusCode
        if status == 409 { return }
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

    struct PromptEntry: Encodable {
        let question: String
        let answer: String
        let isCustom: Bool
        enum CodingKeys: String, CodingKey {
            case question, answer
            case isCustom = "is_custom"
        }
    }

    // Required
    let firstName: String?
    let lastName: String?
    let birthDate: String           // ISO: "1995-03-15"
    let gender: String
    let ethnicity: String?
    let heightUnit: String?         // "imperial" or "metric"
    let heightFt: Int?
    let heightIn: Int?
    let heightCm: Int?
    let locationCity: String
    let locationState: String
    let locationZip: String
    let latitude: Double
    let longitude: Double
    let meetPreference: String
    let relationshipGoals: [String]
    let minAgePreference: Int
    let maxAgePreference: Int
    let distancePreferenceMiles: Int
    // Optional
    let drinks: String?
    let smoking: String?
    let pets: String?
    let children: String?
    let workout: String?
    let sleepSchedule: String?
    let education: String?
    let prompts: [PromptEntry]?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case birthDate = "birth_date"
        case gender
        case ethnicity
        case heightUnit = "height_unit"
        case heightFt = "height_ft"
        case heightIn = "height_in"
        case heightCm = "height_cm"
        case locationCity = "location_city"
        case locationState = "location_state"
        case locationZip = "location_zip"
        case latitude, longitude
        case meetPreference = "meet_preference"
        case relationshipGoals = "relationship_goals"
        case minAgePreference = "min_age_preference"
        case maxAgePreference = "max_age_preference"
        case distancePreferenceMiles = "distance_preference_miles"
        case drinks, smoking, pets, children, workout
        case sleepSchedule = "sleep_schedule"
        case education
        case prompts
    }

    init(from data: OnboardingData, firstName: String, lastName: String) {
        self.firstName = firstName.isEmpty ? nil : firstName
        self.lastName = lastName.isEmpty ? nil : lastName

        // Combine separate dob fields into ISO date string
        let monthMap = ["Jan": "01", "Feb": "02", "Mar": "03", "Apr": "04", "May": "05", "Jun": "06",
                        "Jul": "07", "Aug": "08", "Sep": "09", "Oct": "10", "Nov": "11", "Dec": "12"]
        let monthNum = monthMap[data.dobMonth] ?? "01"
        let day = data.dobDay.count == 1 ? "0\(data.dobDay)" : data.dobDay
        birthDate = "\(data.dobYear)-\(monthNum)-\(day)"

        gender = data.sex
        ethnicity = data.ethnicities.isEmpty ? nil : data.ethnicities.sorted().joined(separator: ", ")

        // Map height unit: "FT" → "imperial", "CM" → "metric"
        let hasHeight = !data.heightFt.isEmpty || !data.heightCm.isEmpty
        if hasHeight {
            let isImperial = data.heightUnit == "FT"
            heightUnit = isImperial ? "imperial" : "metric"
            heightFt = isImperial ? Int(data.heightFt) : nil
            heightIn = isImperial ? (Int(data.heightIn) ?? 0) : nil
            heightCm = isImperial ? nil : Int(data.heightCm)
        } else {
            heightUnit = nil; heightFt = nil; heightIn = nil; heightCm = nil
        }

        locationCity = data.locationCity
        locationState = data.locationState
        locationZip = data.locationZip
        latitude = data.latitude
        longitude = data.longitude

        meetPreference = data.meetPreference
        relationshipGoals = Array(data.relationshipGoals)
        minAgePreference = Int(data.minAge)
        maxAgePreference = Int(data.maxAge)
        distancePreferenceMiles = Int(data.distance)

        drinks = data.drinks.isEmpty ? nil : data.drinks
        smoking = data.smoking.isEmpty ? nil : data.smoking
        pets = data.pets.isEmpty ? nil : data.pets
        children = data.children.isEmpty ? nil : data.children
        workout = data.workout.isEmpty ? nil : data.workout
        sleepSchedule = data.sleepSchedule.isEmpty ? nil : data.sleepSchedule
        education = data.education.isEmpty ? nil : data.education

        // Build prompts array from individual prompt fields
        var promptList: [PromptEntry] = []
        if !data.prompt1Question.isEmpty && !data.prompt1Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt1Question, answer: data.prompt1Answer, isCustom: false))
        }
        if !data.prompt2Question.isEmpty && !data.prompt2Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt2Question, answer: data.prompt2Answer, isCustom: false))
        }
        if !data.prompt3Question.isEmpty && !data.prompt3Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt3Question, answer: data.prompt3Answer, isCustom: false))
        }
        if !data.ownPrompt.isEmpty && !data.ownPromptAnswer.isEmpty {
            promptList.append(PromptEntry(question: data.ownPrompt, answer: data.ownPromptAnswer, isCustom: true))
        }
        prompts = promptList.isEmpty ? nil : promptList
    }
}
