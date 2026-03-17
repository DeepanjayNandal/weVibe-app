import Foundation
import Observation
import FirebaseAuth

// MARK: - MatchProfile (data model for viewing another user's profile)

struct MatchProfile: Identifiable {
    var id: String
    var firstName: String
    var lastName: String
    var age: Int
    var jobTitle: String
    var bio: String
    var pronouns: String
    var instagramHandle: String?
    var tiktokHandle: String?
    var locationCity: String
    var locationState: String
    var orientation: String?
    var identity: String?
    var personalityType: String?
    var loveLanguage: String?
    var zodiacSign: String?
    var interests: [String]
    var preferredDateActivities: [String]
    var drinks: String
    var smoking: String
    var cannabis: String
    var workout: String
    var sleepSchedule: String
    var pets: String
    var petTypes: String
    var career: String
    var school: String
    var education: String
    var ethnicities: [String]
    var languages: [String]
    var photoURLs: [String]
    var prompts: [PromptPair]
    var socialMediaLinks: [String]

    // What this user has chosen to show on their profile
    var showLocation: Bool
    var showOrientation: Bool
    var showPersonalityTrait: Bool
    var showInterests: Bool
    var showLifestyle: Bool
    var showCareer: Bool
    var showPets: Bool

    var fullName: String { "\(firstName) \(lastName)" }

    struct PromptPair: Identifiable {
        var id: String { question }
        var question: String
        var answer: String
    }

    // MARK: - Mock Data
    static let mock = MatchProfile(
        id: "mock-1",
        firstName: "Jessica",
        lastName: "Parker",
        age: 23,
        jobTitle: "Professional Model",
        bio: "Adventure seeker, coffee lover, and part-time explorer. Looking for someone who appreciates both deep conversations and spontaneous road trips.",
        pronouns: "she/her",
        instagramHandle: "jessicap",
        tiktokHandle: "jessparker",
        locationCity: "Chicago",
        locationState: "IL",
        orientation: "Straight",
        identity: nil,
        personalityType: "Protagonist (ENFJ)",
        loveLanguage: "Quality Time",
        zodiacSign: "Leo",
        interests: ["Travel", "Photography", "Music", "Reading", "Fitness", "Dance"],
        preferredDateActivities: ["Dinner & a movie", "Exploring the city", "Live music at a bar"],
        drinks: "Sometimes",
        smoking: "Never",
        cannabis: "Never",
        workout: "Often",
        sleepSchedule: "Night Owl",
        pets: "Have",
        petTypes: "Dog",
        career: "Arts",
        school: "Northwestern University",
        education: "Bachelor's Degree",
        ethnicities: ["White", "Hispanic/Latino"],
        languages: ["English", "Spanish"],
        photoURLs: [
            "https://picsum.photos/seed/wv1/400/600",
            "https://picsum.photos/seed/wv2/400/600",
            "https://picsum.photos/seed/wv3/400/600",
            "https://picsum.photos/seed/wv4/400/600",
            "https://picsum.photos/seed/wv5/400/600",
            "https://picsum.photos/seed/wv6/400/600",
        ], // mock photos for MatchProfile preview
        prompts: [
            .init(question: "A perfect day for me looks like...", answer: "Waking up late, grabbing coffee at a local cafe, exploring a new neighborhood, and ending the evening with great music and company."),
            .init(question: "The most spontaneous thing I've done is...", answer: "Booked a last-minute flight to Paris with nothing but a backpack and a sense of adventure."),
        ],
        socialMediaLinks: [],
        showLocation: true,
        showOrientation: true,
        showPersonalityTrait: true,
        showInterests: true,
        showLifestyle: true,
        showCareer: true,
        showPets: true
    )
}

// MARK: - UserProfileStore

/// Holds all extended profile fields not captured during onboarding.
/// Provides mock GET/PATCH API and UserDefaults persistence until the real backend is ready.
@Observable
final class UserProfileStore {

    // MARK: - About
    var bio: String = ""
    var jobTitle: String = ""
    var school: String = ""
    var instagramHandle: String = ""
    var tiktokHandle: String = ""

    // MARK: - Identity
    var orientation: String = ""
    var showOrientation: Bool = true
    var identity: String = ""
    var showIdentity: Bool = true
    var pronouns: String = ""

    // MARK: - Family
    var children: String = ""       // "Don't want" / "Unsure" / "Want" / "Have"

    // MARK: - Background
    var birthCountry: String = ""
    var ethnicities: [String] = []
    var languages: [String] = []

    // MARK: - Career & Education
    var career: String = ""
    var education: String = ""
    var heightFt: String = ""
    var heightIn: String = ""
    var heightCm: String = ""
    var heightUnit: String = "FT"

    // MARK: - Lifestyle (from onboarding)
    var drinks: String = ""
    var smoking: String = ""
    var workout: String = ""
    var sleepSchedule: String = ""
    var pets: String = ""

    // MARK: - Lifestyle (additional)
    var cannabis: String = ""       // "Never" / "Sometimes" / "Often"
    var isCannabisFlexible: Bool = false
    var petTypes: String = ""       // what kind of pets
    var petsName: String = ""

    // MARK: - Lifestyle Flexibility (are they okay if a match differs?)
    var isDrinksFlexible: Bool = false
    var isSmokingFlexible: Bool = false
    var isWorkoutFlexible: Bool = false
    var isSleepFlexible: Bool = false
    var isKidsFlexible: Bool = false

    // MARK: - Personality & Fun
    var loveLanguage: String = ""
    var zodiacSign: String = ""
    var communicationStyle: String = ""     // "Texter" or "Phone Person"
    var conflictStyle: String = ""          // "Quiet & Reserved" or "Address it head-on"
    var personalityType: String = ""        // 16personalities result

    // MARK: - Interests & Activities
    var interests: [String] = []
    var preferredDateActivities: [String] = []
    var wouldNotDoActivities: [String] = []

    // MARK: - Dating Preferences
    var relationshipGoals: [String] = []
    var meetPreference: String = ""
    var minAge: Double = 18
    var maxAge: Double = 50
    var distance: Double = 25

    // MARK: - Name
    var firstName: String = ""
    var lastName: String = ""

    // MARK: - Prompts
    var prompt1Question: String = ""
    var prompt1Answer: String = ""
    var prompt2Question: String = ""
    var prompt2Answer: String = ""
    var prompt3Question: String = ""
    var prompt3Answer: String = ""
    var customPromptQuestion: String = ""
    var customPromptAnswer: String = ""

    // MARK: - Social Media
    var socialMediaLinks: [String] = ["", "", ""]
    var spotifyPlaylistURL: String = ""
    var photoURLs: [String] = []

    // MARK: - Field Visibility (shown to other users)
    var showSex: Bool = true
    var showLocation: Bool = true
    var showPersonalityTrait: Bool = true
    var showInterests: Bool = true
    var showLifestyle: Bool = true
    var showCareer: Bool = true
    var showPets: Bool = true

    // MARK: - Load State
    var isLoading: Bool = false

    private static let storageKey = "wevibe_profile_ext_v4"
    private let apiClient = APIClient()

    init() { load() }

    // MARK: - Onboarding Seed

    /// Copies onboarding answers into the store the first time the profile tab is shown.
    /// No-ops once the user has saved any profile edit (UserDefaults key will exist).
    func seedIfNeeded(from onboarding: OnboardingData) {
        guard UserDefaults.standard.data(forKey: Self.storageKey) == nil else { return }
        drinks        = onboarding.drinks
        smoking       = onboarding.smoking
        pets          = onboarding.pets
        children      = onboarding.children
        workout       = onboarding.workout
        sleepSchedule = onboarding.sleepSchedule
        education     = onboarding.education
        career        = onboarding.career
        heightFt      = onboarding.heightFt
        heightIn      = onboarding.heightIn
        heightCm      = onboarding.heightCm
        heightUnit    = onboarding.heightUnit
        meetPreference    = onboarding.meetPreference
        minAge            = onboarding.minAge
        maxAge            = onboarding.maxAge
        distance          = onboarding.distance
        relationshipGoals     = Array(onboarding.relationshipGoals)
        prompt1Question       = onboarding.prompt1Question
        prompt1Answer         = onboarding.prompt1Answer
        prompt2Question       = onboarding.prompt2Question
        prompt2Answer         = onboarding.prompt2Answer
        prompt3Question       = onboarding.prompt3Question
        prompt3Answer         = onboarding.prompt3Answer
        customPromptQuestion  = onboarding.ownPrompt
        customPromptAnswer    = onboarding.ownPromptAnswer
        save()
    }

    // MARK: - API

    /// GET /users/profile — fetches full profile from backend and updates the store.
    /// Falls back to local cache silently on network or auth errors.
    func fetchProfile() async {
        isLoading = true
        defer { isLoading = false }
        guard let user = Auth.auth().currentUser else { return }
        do {
            let token = try await user.getIDToken()
            let response = try await apiClient.getProfile(token: token)
            apply(response: response)
            save()
        } catch {
            // Keep locally persisted data on failure
        }
    }

    /// PATCH /users/profile — persists locally first, then syncs to backend.
    func patchProfile() async {
        save()
        guard let user = Auth.auth().currentUser else { return }
        do {
            let token = try await user.getIDToken()
            let payload = ProfileUpdatePayload(from: self)
            try await apiClient.updateProfile(token: token, payload: payload)
        } catch {
            // Local save already succeeded — backend will sync on next fetch
        }
    }

    // MARK: - Apply GET Response

    private func apply(response r: UserProfileResponse) {
        if let v = r.firstName         { firstName        = v }
        if let v = r.lastName          { lastName         = v }
        if let v = r.bio               { bio              = v }
        if let v = r.jobTitle          { jobTitle         = v }
        if let v = r.school            { school           = v }
        if let v = r.instagramHandle   { instagramHandle  = v }
        if let v = r.tiktokHandle      { tiktokHandle     = v }
        if let v = r.spotifyPlaylistUrl { spotifyPlaylistURL = v }
        if let v = r.pronouns          { pronouns         = v }
        if let v = r.orientation       { orientation      = v }
        if let v = r.showOrientation   { showOrientation  = v }
        if let v = r.genderIdentity    { identity         = v }
        if let v = r.showIdentity      { showIdentity     = v }
        if let v = r.showGender        { showSex          = v }
        if let v = r.careerField       { career           = v }
        if let v = r.education         { education        = EducationLevel(rawValue: v)?.displayName ?? v }
        if let unit = r.heightUnit {
            heightUnit = unit == "imperial" ? "FT" : "CM"
            if unit == "imperial" {
                heightFt = r.heightFt.map { String($0) } ?? ""
                heightIn = r.heightIn.map { String($0) } ?? ""
                heightCm = ""
            } else {
                heightCm = r.heightCm.map { String($0) } ?? ""
                heightFt = ""; heightIn = ""
            }
        }
        if let v = r.ethnicity              { ethnicities           = v }
        if let v = r.languages             { languages             = v }
        if let v = r.birthCountry          { birthCountry          = v }
        if let v = r.drinks                { drinks                = v }
        if let v = r.smoking               { smoking               = v }
        if let v = r.workout               { workout               = v }
        if let v = r.sleepSchedule         { sleepSchedule         = v }
        if let v = r.pets                  { pets                  = v }
        if let v = r.cannabis              { cannabis              = v }
        if let v = r.petTypes              { petTypes              = v }
        if let v = r.petsName              { petsName              = v }
        if let v = r.children              { children              = v }
        if let v = r.isDrinksFlexible      { isDrinksFlexible      = v }
        if let v = r.isSmokingFlexible     { isSmokingFlexible     = v }
        if let v = r.isWorkoutFlexible     { isWorkoutFlexible     = v }
        if let v = r.isSleepFlexible       { isSleepFlexible       = v }
        if let v = r.isCannabisFlexible    { isCannabisFlexible    = v }
        if let v = r.isKidsFlexible        { isKidsFlexible        = v }
        if let v = r.loveLanguage          { loveLanguage          = v }
        if let v = r.zodiacSign            { zodiacSign            = v }
        if let v = r.communicationStyle    { communicationStyle    = v }
        if let v = r.conflictStyle         { conflictStyle         = v }
        if let v = r.personalityType       { personalityType       = v }
        if let v = r.interests             { interests             = v }
        if let v = r.preferredDateActivities { preferredDateActivities = v }
        if let v = r.wouldNotDoActivities  { wouldNotDoActivities  = v }
        if let v = r.meetPreference        { meetPreference        = v }
        if let v = r.relationshipGoals     { relationshipGoals     = v }
        if let v = r.minAgePreference      { minAge                = Double(v) }
        if let v = r.maxAgePreference      { maxAge                = Double(v) }
        if let v = r.distancePreferenceMiles { distance            = Double(v) }
        if let v = r.photoUrls             { photoURLs             = v }
        if let prompts = r.prompts {
            prompt1Question      = prompts.count > 0 ? prompts[0].question : ""
            prompt1Answer        = prompts.count > 0 ? prompts[0].answer   : ""
            prompt2Question      = prompts.count > 1 ? prompts[1].question : ""
            prompt2Answer        = prompts.count > 1 ? prompts[1].answer   : ""
            prompt3Question      = prompts.count > 2 ? prompts[2].question : ""
            prompt3Answer        = prompts.count > 2 ? prompts[2].answer   : ""
            customPromptQuestion = prompts.count > 3 ? prompts[3].question : ""
            customPromptAnswer   = prompts.count > 3 ? prompts[3].answer   : ""
        }
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(Draft(from: self)) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let draft = try? JSONDecoder().decode(Draft.self, from: data)
        else { return }
        draft.apply(to: self)
    }

    // MARK: - Codable Mirror

    private struct Draft: Codable {
        var firstName, lastName: String
        var bio, jobTitle, school, instagramHandle, tiktokHandle: String
        var orientation: String; var showOrientation: Bool
        var identity: String; var showIdentity: Bool
        var pronouns, children, birthCountry: String
        var ethnicities, languages: [String]
        var career, education: String
        var heightFt, heightIn, heightCm, heightUnit: String
        var drinks, smoking, workout, sleepSchedule, pets: String
        var cannabis: String; var isCannabisFlexible: Bool
        var petTypes, petsName: String
        var isDrinksFlexible, isSmokingFlexible, isWorkoutFlexible, isSleepFlexible, isKidsFlexible: Bool
        var loveLanguage, zodiacSign: String
        var communicationStyle, conflictStyle: String
        var personalityType: String
        var interests, preferredDateActivities, wouldNotDoActivities: [String]
        var relationshipGoals: [String]
        var meetPreference: String
        var minAge, maxAge, distance: Double
        var prompt1Question, prompt1Answer: String
        var prompt2Question, prompt2Answer: String
        var prompt3Question, prompt3Answer: String
        var customPromptQuestion, customPromptAnswer: String
        var socialMediaLinks: [String]; var spotifyPlaylistURL: String
        var photoURLs: [String]
        var showSex: Bool
        var showLocation, showPersonalityTrait, showInterests: Bool
        var showLifestyle, showCareer, showPets: Bool

        init(from s: UserProfileStore) {
            firstName = s.firstName; lastName = s.lastName
            bio = s.bio; jobTitle = s.jobTitle; school = s.school
            instagramHandle = s.instagramHandle; tiktokHandle = s.tiktokHandle
            orientation = s.orientation; showOrientation = s.showOrientation
            identity = s.identity; showIdentity = s.showIdentity
            pronouns = s.pronouns; children = s.children
            birthCountry = s.birthCountry
            ethnicities = s.ethnicities; languages = s.languages
            career = s.career; education = s.education
            heightFt = s.heightFt; heightIn = s.heightIn; heightCm = s.heightCm; heightUnit = s.heightUnit
            drinks = s.drinks; smoking = s.smoking; workout = s.workout
            sleepSchedule = s.sleepSchedule; pets = s.pets
            cannabis = s.cannabis; isCannabisFlexible = s.isCannabisFlexible
            petTypes = s.petTypes; petsName = s.petsName
            isDrinksFlexible = s.isDrinksFlexible; isSmokingFlexible = s.isSmokingFlexible
            isWorkoutFlexible = s.isWorkoutFlexible; isSleepFlexible = s.isSleepFlexible
            isKidsFlexible = s.isKidsFlexible
            loveLanguage = s.loveLanguage; zodiacSign = s.zodiacSign
            communicationStyle = s.communicationStyle; conflictStyle = s.conflictStyle
            personalityType = s.personalityType
            interests = s.interests
            preferredDateActivities = s.preferredDateActivities
            wouldNotDoActivities = s.wouldNotDoActivities
            relationshipGoals = s.relationshipGoals
            meetPreference = s.meetPreference
            minAge = s.minAge; maxAge = s.maxAge; distance = s.distance
            prompt1Question = s.prompt1Question; prompt1Answer = s.prompt1Answer
            prompt2Question = s.prompt2Question; prompt2Answer = s.prompt2Answer
            prompt3Question = s.prompt3Question; prompt3Answer = s.prompt3Answer
            customPromptQuestion = s.customPromptQuestion; customPromptAnswer = s.customPromptAnswer
            socialMediaLinks = s.socialMediaLinks; spotifyPlaylistURL = s.spotifyPlaylistURL
            photoURLs = s.photoURLs
            showSex = s.showSex
            showLocation = s.showLocation; showPersonalityTrait = s.showPersonalityTrait
            showInterests = s.showInterests; showLifestyle = s.showLifestyle
            showCareer = s.showCareer; showPets = s.showPets
        }

        func apply(to s: UserProfileStore) {
            s.firstName = firstName; s.lastName = lastName
            s.bio = bio; s.jobTitle = jobTitle; s.school = school
            s.instagramHandle = instagramHandle; s.tiktokHandle = tiktokHandle
            s.orientation = orientation; s.showOrientation = showOrientation
            s.identity = identity; s.showIdentity = showIdentity
            s.pronouns = pronouns; s.children = children
            s.birthCountry = birthCountry
            s.ethnicities = ethnicities; s.languages = languages
            s.career = career; s.education = education
            s.heightFt = heightFt; s.heightIn = heightIn; s.heightCm = heightCm; s.heightUnit = heightUnit
            s.drinks = drinks; s.smoking = smoking; s.workout = workout
            s.sleepSchedule = sleepSchedule; s.pets = pets
            s.cannabis = cannabis; s.isCannabisFlexible = isCannabisFlexible
            s.petTypes = petTypes; s.petsName = petsName
            s.isDrinksFlexible = isDrinksFlexible; s.isSmokingFlexible = isSmokingFlexible
            s.isWorkoutFlexible = isWorkoutFlexible; s.isSleepFlexible = isSleepFlexible
            s.isKidsFlexible = isKidsFlexible
            s.loveLanguage = loveLanguage; s.zodiacSign = zodiacSign
            s.communicationStyle = communicationStyle; s.conflictStyle = conflictStyle
            s.personalityType = personalityType
            s.interests = interests
            s.preferredDateActivities = preferredDateActivities
            s.wouldNotDoActivities = wouldNotDoActivities
            s.relationshipGoals = relationshipGoals
            s.meetPreference = meetPreference
            s.minAge = minAge; s.maxAge = maxAge; s.distance = distance
            s.prompt1Question = prompt1Question; s.prompt1Answer = prompt1Answer
            s.prompt2Question = prompt2Question; s.prompt2Answer = prompt2Answer
            s.prompt3Question = prompt3Question; s.prompt3Answer = prompt3Answer
            s.customPromptQuestion = customPromptQuestion; s.customPromptAnswer = customPromptAnswer
            s.socialMediaLinks = socialMediaLinks; s.spotifyPlaylistURL = spotifyPlaylistURL
            s.photoURLs = photoURLs
            s.showSex = showSex
            s.showLocation = showLocation; s.showPersonalityTrait = showPersonalityTrait
            s.showInterests = showInterests; s.showLifestyle = showLifestyle
            s.showCareer = showCareer; s.showPets = showPets
        }
    }
}

// MARK: - Static Option Lists

extension UserProfileStore {
    // BinarySlider needs empty string in the middle for the neutral position
    static let communicationStyleOptions = ["Big Texter", "", "Phone Person"]
    static let conflictStyleOptions      = ["Quiet & Reserved", "", "Confrontational"]

    static let orientationOptions      = SexualOrientation.allCases.map(\.rawValue)
    static let identityOptions         = GenderIdentity.allCases.map(\.rawValue)
    static let loveLanguageOptions     = LoveLanguage.allCases.map(\.rawValue)
    static let zodiacOptions           = ZodiacSign.allCases.map(\.rawValue)
    static let childrenOptions         = FamilyPreference.allCases.map(\.rawValue)
    static let cannabisOptions         = FrequencyHabit.allCases.map(\.rawValue)
    static let relationshipGoalOptions = RelationshipGoal.allCases.map(\.rawValue)
    static let meetPreferenceOptions   = MeetPreference.allCases.map(\.rawValue)

    static let interestOptions = [
        "Travel", "Photography", "Music", "Reading", "Fitness", "Dance",
        "Cooking", "Gaming", "Art", "Sports", "Movies", "Yoga",
        "Hiking", "Fashion", "Technology", "Foodie", "Outdoors", "K-Pop",
        "Shopping", "Concerts", "Skiing", "Running", "Tattoos", "Climbing",
        "Swimming", "Festivals", "Start-ups", "Collecting", "Road Trips", "Boba Tea",
        "Coffee", "Dogs", "Cats", "Activism", "Football", "Basketball",
        "Soccer", "Crossfit", "Aquarium", "Nature", "Cars", "Sneakers",
        "90s Kid", "Country Music", "LGBTQ+ Rights", "Climate Change"
    ]
    static let dateActivityOptions = [
        "Dinner & a movie", "Coffee at a local cafe", "Exploring the city",
        "Night out at the club", "Live music at a bar", "Lunch & a museum",
        "Something active & adventurous", "Concert", "Hiking", "Cooking together",
        "Picnic", "Art gallery", "Sports game", "Comedy show", "Rooftop bar"
    ]
}
