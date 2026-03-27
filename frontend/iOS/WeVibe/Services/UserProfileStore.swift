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
    
    var isPersonalityTestCompelte: Bool
    var personalityType: String?
    var personalityPrimary: String?
    var personalitySecondary: String?
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

}

// MARK: - UserProfileStore

/// In-memory store for the authenticated user's full profile.
/// Data is fetched from the backend on app launch and after every PATCH — no local caching.
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

    // MARK: - Core (synced from backend, set during onboarding)
    var birthDate: String = ""      // ISO YYYY-MM-DD
    var sex: String = ""            // "Male" / "Female" / "Non-binary" etc.
    var locationCity: String = ""
    var locationState: String = ""

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
    var photos: [UserPhoto] = []

    // MARK: - Field Visibility (shown to other users)
    var showSex: Bool = true
    var showLocation: Bool = true
    var showPersonalityTrait: Bool = true
    var showInterests: Bool = true
    var showLifestyle: Bool = true
    var showCareer: Bool = true
    var showPets: Bool = true
    
    // MARK: Personality Test Data
    var isPersonalityTestComplete: Bool = true
    var personalityType: String = ""        // 16personalities result
    var personalityPrimary: String = ""
    var personalitySecondary: String = ""

    // MARK: - Load State
    var isLoading: Bool = false
    var fetchFailed: Bool = false
    var patchError: String? = nil

    private let apiClient = APIClient()

    // MARK: - API

    /// GET /users/profile — fetches full profile from backend and updates the store.
    func fetchProfile() async {
        isLoading = true
        fetchFailed = false
        defer { isLoading = false }
        guard let user = Auth.auth().currentUser else { return }
        do {
            let token = try await user.getIDToken()
            let response = try await apiClient.getProfile(token: token)
            apply(response: response)
        } catch {
            fetchFailed = true
        }
    }

    /// PATCH /users/profile — sends only the changed fields, then re-fetches to confirm saved state.
    /// Pass a targeted `ProfileUpdatePayload` to send only the fields that changed.
    /// Omit the payload to send all non-empty fields (used by onboarding and legacy call sites).
    func patchProfile(_ payload: ProfileUpdatePayload? = nil) async {
        patchError = nil
        guard let user = Auth.auth().currentUser else { return }
        do {
            let token = try await user.getIDToken()
            let p = payload ?? ProfileUpdatePayload(from: self)
            try await apiClient.updateProfile(token: token, payload: p)
            // Re-fetch so the store reflects exactly what the backend saved
            await fetchProfile()
        } catch {
            patchError = "Failed to save. Please try again."
        }
    }
    
    /// POST /users/profile/personality - update field personality test data
    func postPersonalityTest(answers: [Int]) async {
        patchError = nil
        guard let user = Auth.auth().currentUser else { return }
        do {
            let token = try await user.getIDToken()
            let response = try await apiClient.updatePersonalityData(token: token, answers: answers)
     
            personalityType = response.personalityType
            personalityPrimary = response.personalityPrimary
            personalitySecondary = response.personalitySecondary ?? ""
     
        } catch {
            patchError = "Failed to save personality test. Please try again."
        }
    }

    // MARK: - Apply GET Response

    private func apply(response r: UserProfileResponse) {
        if let v = r.firstName         { firstName        = v }
        if let v = r.lastName          { lastName         = v }
        if let v = r.birthDate         { birthDate        = v }
        if let v = r.gender            { sex              = v }
        if let v = r.locationCity      { locationCity     = v }
        if let v = r.locationState     { locationState    = v }
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
        if let v = r.personalityPrimary    {personalityPrimary     = v }
        if let v = r.personalitySecondary  {personalitySecondary   = v }
        
        if let v = r.interests             { interests             = v }
        if let v = r.preferredDateActivities { preferredDateActivities = v }
        if let v = r.wouldNotDoActivities  { wouldNotDoActivities  = v }
        if let v = r.meetPreference        { meetPreference        = v }
        if let v = r.relationshipGoals     { relationshipGoals     = v }
        if let v = r.minAgePreference      { minAge                = Double(v) }
        if let v = r.maxAgePreference      { maxAge                = Double(v) }
        if let v = r.distancePreferenceMiles { distance            = Double(v) }
        if let v = r.photos                { photos                = v }
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

    // MARK: - Clear (called on logout)

    func clear() {
        bio = ""; jobTitle = ""; school = ""; instagramHandle = ""; tiktokHandle = ""
        orientation = ""; showOrientation = true; identity = ""; showIdentity = true; pronouns = ""
        children = ""; birthCountry = ""; ethnicities = []; languages = []
        career = ""; education = ""
        heightFt = ""; heightIn = ""; heightCm = ""; heightUnit = "FT"
        drinks = ""; smoking = ""; workout = ""; sleepSchedule = ""; pets = ""
        cannabis = ""; isCannabisFlexible = false; petTypes = ""; petsName = ""
        isDrinksFlexible = false; isSmokingFlexible = false; isWorkoutFlexible = false
        isSleepFlexible = false; isKidsFlexible = false
        loveLanguage = ""; zodiacSign = ""; communicationStyle = ""; conflictStyle = ""; personalityType = ""; isPersonalityTestComplete = false; personalityPrimary = ""; personalitySecondary = "";
        interests = []; preferredDateActivities = []; wouldNotDoActivities = []
        relationshipGoals = []; meetPreference = ""; minAge = 18; maxAge = 50; distance = 25
        firstName = ""; lastName = ""; birthDate = ""; sex = ""; locationCity = ""; locationState = ""
        prompt1Question = ""; prompt1Answer = ""; prompt2Question = ""; prompt2Answer = ""
        prompt3Question = ""; prompt3Answer = ""; customPromptQuestion = ""; customPromptAnswer = ""
        socialMediaLinks = ["", "", ""]; spotifyPlaylistURL = ""; photos = []
        showSex = true; showLocation = true; showPersonalityTrait = true
        showInterests = true; showLifestyle = true; showCareer = true; showPets = true
        fetchFailed = false
        patchError = nil
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
