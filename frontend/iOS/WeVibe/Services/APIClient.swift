import Foundation

private struct ErrorResponse: Decodable {
    struct ErrorBody: Decodable { let code: String }
    let error: ErrorBody
}

private struct MeResponse: Decodable {
    struct DataBody: Decodable {
        struct UserBody: Decodable { let onboardingComplete: Bool }
        let user: UserBody
    }
    let data: DataBody
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

    /// GET /auth/me — returns true if onboarding is complete, false if not yet done.
    func checkProfile(token: String) async throws -> Bool {
        let req = request(path: "/auth/me", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 200 {
            let me = try JSONDecoder().decode(MeResponse.self, from: data)
            return me.data.user.onboardingComplete
        }
        if status == 401 { throw APIError.unauthorized }
        throw APIError.serverError(status)
    }

    /// POST /users/profile — submits onboarding data to create the user profile.
    func submitProfile(token: String, payload: UserProfilePayload) async throws {
        var req = request(path: "/users/profile", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await perform(req)
        let status = response.statusCode
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
        let status = response.statusCode
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
        let status = response.statusCode
        if status == 409 { return }
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    // MARK: - Profile

    /// GET /users/profile — fetches the full user profile for the profile tab.
    func getProfile(token: String) async throws -> UserProfileResponse {
        let req = request(path: "/users/profile", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
        do {
            return try JSONDecoder().decode(UserProfileResponse.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// PATCH /users/profile — updates profile fields. Only sent fields are updated.
    func updateProfile(token: String, payload: ProfileUpdatePayload) async throws {
        var req = request(path: "/users/profile", method: "PATCH", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await perform(req)
        let status = response.statusCode
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

    private func perform(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.network(URLError(.badServerResponse))
            }
            return (data, httpResponse)
        } catch let error as APIError {
            throw error
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
    }

    // Required
    let firstName: String?
    let lastName: String?
    let birthDate: String           // ISO: "1995-03-15"
    let gender: String
    let ethnicity: [String]?
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
    let careerField: String?
    let languages: [String]?
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
        case careerField = "career_field"
        case languages
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
        ethnicity = data.ethnicities.isEmpty ? nil : data.ethnicities.sorted()

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
        let educationMap: [String: String] = [
            "High School": "high_school",
            "In College": "in_college",
            "Bachelor's Degree": "bachelors",
            "Master's Degree": "masters",
            "PhD / Doctorate": "phd",
            "Other": "other"
        ]
        education = data.education.isEmpty ? nil : (educationMap[data.education] ?? data.education)
        careerField = data.career.isEmpty ? nil : data.career
        languages = data.languages.isEmpty ? nil : data.languages.sorted()

        // Build prompts array from individual prompt fields
        var promptList: [PromptEntry] = []
        if !data.prompt1Question.isEmpty && !data.prompt1Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt1Question, answer: data.prompt1Answer))
        }
        if !data.prompt2Question.isEmpty && !data.prompt2Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt2Question, answer: data.prompt2Answer))
        }
        if !data.prompt3Question.isEmpty && !data.prompt3Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt3Question, answer: data.prompt3Answer))
        }
        if !data.ownPrompt.isEmpty && !data.ownPromptAnswer.isEmpty {
            promptList.append(PromptEntry(question: data.ownPrompt, answer: data.ownPromptAnswer))
        }
        prompts = promptList.isEmpty ? nil : promptList
    }
}

// MARK: - Profile GET Response

struct UserProfileResponse: Decodable {
    struct PromptEntry: Decodable { let question: String; let answer: String }

    let firstName: String?
    let lastName: String?
    let bio: String?
    let jobTitle: String?
    let instagramHandle: String?
    let tiktokHandle: String?
    let spotifyPlaylistUrl: String?
    let pronouns: String?
    let orientation: String?
    let genderIdentity: String?
    let showGender: Bool?
    let showOrientation: Bool?
    let showIdentity: Bool?
    let careerField: String?
    let education: String?
    let school: String?
    let heightUnit: String?
    let heightFt: Int?
    let heightIn: Int?
    let heightCm: Int?
    let ethnicity: [String]?
    let languages: [String]?
    let birthCountry: String?
    let drinks: String?
    let smoking: String?
    let workout: String?
    let sleepSchedule: String?
    let pets: String?
    let cannabis: String?
    let petTypes: String?
    let petsName: String?
    let children: String?
    let isDrinksFlexible: Bool?
    let isSmokingFlexible: Bool?
    let isWorkoutFlexible: Bool?
    let isSleepFlexible: Bool?
    let isCannabisFlexible: Bool?
    let isKidsFlexible: Bool?
    let loveLanguage: String?
    let zodiacSign: String?
    let communicationStyle: String?
    let conflictStyle: String?
    let personalityType: String?
    let interests: [String]?
    let preferredDateActivities: [String]?
    let wouldNotDoActivities: [String]?
    let meetPreference: String?
    let relationshipGoals: [String]?
    let minAgePreference: Int?
    let maxAgePreference: Int?
    let distancePreferenceMiles: Int?
    let birthDate: String?
    let gender: String?
    let locationCity: String?
    let locationState: String?
    let prompts: [PromptEntry]?
    let photoUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case bio
        case jobTitle = "job_title"
        case instagramHandle = "instagram_handle"
        case tiktokHandle = "tiktok_handle"
        case spotifyPlaylistUrl = "spotify_playlist_url"
        case pronouns, orientation
        case genderIdentity = "gender_identity"
        case showGender = "show_sex"
        case showOrientation = "show_orientation"
        case showIdentity = "show_identity"
        case careerField = "career_field"
        case education, school
        case heightUnit = "height_unit"
        case heightFt = "height_ft"
        case heightIn = "height_in"
        case heightCm = "height_cm"
        case ethnicity, languages
        case birthCountry = "birth_country"
        case drinks, smoking, workout
        case sleepSchedule = "sleep_schedule"
        case pets, cannabis
        case petTypes = "pet_types"
        case petsName = "pets_name"
        case children
        case isDrinksFlexible = "is_drinks_flexible"
        case isSmokingFlexible = "is_smoking_flexible"
        case isWorkoutFlexible = "is_workout_flexible"
        case isSleepFlexible = "is_sleep_flexible"
        case isCannabisFlexible = "is_cannabis_flexible"
        case isKidsFlexible = "is_kids_flexible"
        case loveLanguage = "love_language"
        case zodiacSign = "zodiac_sign"
        case communicationStyle = "communication_style"
        case conflictStyle = "conflict_style"
        case personalityType = "personality_type"
        case interests
        case preferredDateActivities = "preferred_date_activities"
        case wouldNotDoActivities = "would_not_do_activities"
        case meetPreference = "meet_preference"
        case relationshipGoals = "relationship_goals"
        case minAgePreference = "min_age_preference"
        case maxAgePreference = "max_age_preference"
        case distancePreferenceMiles = "distance_preference_miles"
        case prompts
        case photoUrls = "photo_urls"
        case birthDate = "birth_date"
        case gender
        case locationCity = "location_city"
        case locationState = "location_state"
    }
}

// MARK: - Profile PATCH Payload

struct ProfileUpdatePayload: Encodable {
    struct PromptEntry: Encodable { let question: String; let answer: String }

    var firstName: String?
    var lastName: String?
    var bio: String?
    var jobTitle: String?
    var instagramHandle: String?
    var tiktokHandle: String?
    var spotifyPlaylistUrl: String?
    var pronouns: String?
    var orientation: String?
    var showGender: Bool?
    var showOrientation: Bool?
    var genderIdentity: String?
    var showIdentity: Bool?
    var careerField: String?
    var education: String?
    var school: String?
    var heightUnit: String?
    var heightFt: Int?
    var heightIn: Int?
    var heightCm: Int?
    var ethnicity: [String]?
    var languages: [String]?
    var birthCountry: String?
    var drinks: String?
    var smoking: String?
    var workout: String?
    var sleepSchedule: String?
    var pets: String?
    var cannabis: String?
    var petTypes: String?
    var petsName: String?
    var children: String?
    var isDrinksFlexible: Bool?
    var isSmokingFlexible: Bool?
    var isWorkoutFlexible: Bool?
    var isSleepFlexible: Bool?
    var isCannabisFlexible: Bool?
    var isKidsFlexible: Bool?
    var loveLanguage: String?
    var zodiacSign: String?
    var communicationStyle: String?
    var conflictStyle: String?
    var interests: [String]?
    var preferredDateActivities: [String]?
    var wouldNotDoActivities: [String]?
    var meetPreference: String?
    var relationshipGoals: [String]?
    var minAgePreference: Int?
    var maxAgePreference: Int?
    var distancePreferenceMiles: Int?
    var prompts: [PromptEntry]?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case bio
        case jobTitle = "job_title"
        case instagramHandle = "instagram_handle"
        case tiktokHandle = "tiktok_handle"
        case spotifyPlaylistUrl = "spotify_playlist_url"
        case pronouns, orientation
        case showGender = "show_sex"
        case showOrientation = "show_orientation"
        case genderIdentity = "gender_identity"
        case showIdentity = "show_identity"
        case careerField = "career_field"
        case education, school
        case heightUnit = "height_unit"
        case heightFt = "height_ft"
        case heightIn = "height_in"
        case heightCm = "height_cm"
        case ethnicity, languages
        case birthCountry = "birth_country"
        case drinks, smoking, workout
        case sleepSchedule = "sleep_schedule"
        case pets, cannabis
        case petTypes = "pet_types"
        case petsName = "pets_name"
        case children
        case isDrinksFlexible = "is_drinks_flexible"
        case isSmokingFlexible = "is_smoking_flexible"
        case isWorkoutFlexible = "is_workout_flexible"
        case isSleepFlexible = "is_sleep_flexible"
        case isCannabisFlexible = "is_cannabis_flexible"
        case isKidsFlexible = "is_kids_flexible"
        case loveLanguage = "love_language"
        case zodiacSign = "zodiac_sign"
        case communicationStyle = "communication_style"
        case conflictStyle = "conflict_style"
        case interests
        case preferredDateActivities = "preferred_date_activities"
        case wouldNotDoActivities = "would_not_do_activities"
        case meetPreference = "meet_preference"
        case relationshipGoals = "relationship_goals"
        case minAgePreference = "min_age_preference"
        case maxAgePreference = "max_age_preference"
        case distancePreferenceMiles = "distance_preference_miles"
        case prompts
    }

    init(from store: UserProfileStore) {
        firstName    = store.firstName.isEmpty    ? nil : store.firstName
        lastName     = store.lastName.isEmpty     ? nil : store.lastName
        bio          = store.bio.isEmpty          ? nil : store.bio
        jobTitle     = store.jobTitle.isEmpty     ? nil : store.jobTitle
        instagramHandle  = store.instagramHandle.isEmpty  ? nil : store.instagramHandle
        tiktokHandle     = store.tiktokHandle.isEmpty     ? nil : store.tiktokHandle
        spotifyPlaylistUrl = store.spotifyPlaylistURL.isEmpty ? nil : store.spotifyPlaylistURL
        pronouns     = store.pronouns.isEmpty     ? nil : store.pronouns
        orientation  = store.orientation.isEmpty  ? nil : store.orientation
        showGender      = store.showSex
        showOrientation = store.showOrientation
        genderIdentity  = store.identity.isEmpty  ? nil : store.identity
        showIdentity    = store.showIdentity
        careerField  = store.career.isEmpty    ? nil : store.career
        education    = store.education.isEmpty ? nil : (EducationLevel.from(displayName: store.education)?.rawValue ?? store.education)
        school       = store.school.isEmpty    ? nil : store.school

        let isImperial = store.heightUnit == "FT"
        if !store.heightFt.isEmpty || !store.heightCm.isEmpty {
            heightUnit = isImperial ? "imperial" : "metric"
            heightFt   = isImperial ? Int(store.heightFt) : nil
            heightIn   = isImperial ? (Int(store.heightIn) ?? 0) : nil
            heightCm   = isImperial ? nil : Int(store.heightCm)
        }

        ethnicity    = store.ethnicities.isEmpty ? nil : store.ethnicities
        languages    = store.languages.isEmpty   ? nil : store.languages
        birthCountry = store.birthCountry.isEmpty ? nil : store.birthCountry
        drinks       = store.drinks.isEmpty       ? nil : store.drinks
        smoking      = store.smoking.isEmpty      ? nil : store.smoking
        workout      = store.workout.isEmpty      ? nil : store.workout
        sleepSchedule = store.sleepSchedule.isEmpty ? nil : store.sleepSchedule
        pets         = store.pets.isEmpty         ? nil : store.pets
        cannabis     = store.cannabis.isEmpty     ? nil : store.cannabis
        petTypes     = store.petTypes.isEmpty     ? nil : store.petTypes
        petsName     = store.petsName.isEmpty     ? nil : store.petsName
        children     = store.children.isEmpty     ? nil : store.children
        isDrinksFlexible   = store.isDrinksFlexible
        isSmokingFlexible  = store.isSmokingFlexible
        isWorkoutFlexible  = store.isWorkoutFlexible
        isSleepFlexible    = store.isSleepFlexible
        isCannabisFlexible = store.isCannabisFlexible
        isKidsFlexible     = store.isKidsFlexible
        loveLanguage = store.loveLanguage.isEmpty ? nil : store.loveLanguage
        zodiacSign   = store.zodiacSign.isEmpty   ? nil : store.zodiacSign
        // Empty string = neutral slider position — only send if non-empty
        communicationStyle = store.communicationStyle.isEmpty ? nil : store.communicationStyle
        conflictStyle      = store.conflictStyle.isEmpty      ? nil : store.conflictStyle
        interests              = store.interests.isEmpty              ? nil : store.interests
        preferredDateActivities = store.preferredDateActivities.isEmpty ? nil : store.preferredDateActivities
        wouldNotDoActivities    = store.wouldNotDoActivities.isEmpty    ? nil : store.wouldNotDoActivities
        meetPreference   = store.meetPreference.isEmpty   ? nil : store.meetPreference
        relationshipGoals = store.relationshipGoals.isEmpty ? nil : store.relationshipGoals
        minAgePreference        = Int(store.minAge)
        maxAgePreference        = Int(store.maxAge)
        distancePreferenceMiles = Int(store.distance)
        var promptList: [PromptEntry] = []
        if !store.prompt1Question.isEmpty && !store.prompt1Answer.isEmpty {
            promptList.append(.init(question: store.prompt1Question, answer: store.prompt1Answer))
        }
        if !store.prompt2Question.isEmpty && !store.prompt2Answer.isEmpty {
            promptList.append(.init(question: store.prompt2Question, answer: store.prompt2Answer))
        }
        if !store.prompt3Question.isEmpty && !store.prompt3Answer.isEmpty {
            promptList.append(.init(question: store.prompt3Question, answer: store.prompt3Answer))
        }
        if !store.customPromptQuestion.isEmpty && !store.customPromptAnswer.isEmpty {
            promptList.append(.init(question: store.customPromptQuestion, answer: store.customPromptAnswer))
        }
        prompts = promptList.isEmpty ? nil : promptList
    }

    /// Empty payload — set only the fields relevant to the calling edit sheet.
    init() {}
}
