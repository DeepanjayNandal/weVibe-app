import Foundation
import Observation

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
    var hasKids: String = ""        // "Yes" / "No"
    var wantsKids: String = ""      // "Yes" / "No" / "Not for a while" / "Maybe"

    // MARK: - Background
    var birthCountry: String = ""

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

    // MARK: - Social Media
    var socialMediaLinks: [String] = ["", "", ""]
    var spotifyPlaylistURL: String = ""
    var photoURLs: [String] = []

    // MARK: - Field Visibility (shown to other users)
    var showLocation: Bool = true
    var showPersonalityTrait: Bool = true
    var showInterests: Bool = true
    var showLifestyle: Bool = true
    var showCareer: Bool = true
    var showPets: Bool = true

    // MARK: - Load State
    var isLoading: Bool = false

    private static let storageKey = "wevibe_profile_ext_v1"

    init() { load() }

    // MARK: - Mock API

    /// Mock GET /users/profile — loads from local cache, seeds mock data on first launch.
    /// TODO: replace with real network call that decodes UserProfileResponse and applies all fields.
    func fetchProfile() async {
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 500_000_000)
        // Seed mock photos on first launch so the carousel is visible during development
        if photoURLs.isEmpty {
            photoURLs = [
                "https://picsum.photos/seed/wv1/400/600",
                "https://picsum.photos/seed/wv2/400/600",
                "https://picsum.photos/seed/wv3/400/600",
                "https://picsum.photos/seed/wv4/400/600",
                "https://picsum.photos/seed/wv5/400/600",
                "https://picsum.photos/seed/wv6/400/600",
            ]
            save()
        }
    }

    /// Mock PATCH /users/profile — persists locally.
    /// TODO: replace body with URLSession call sending a JSON payload of changed fields.
    func patchProfile() async {
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 300_000_000)
        save()
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
        var bio, jobTitle, school, instagramHandle, tiktokHandle: String
        var orientation: String; var showOrientation: Bool
        var identity: String; var showIdentity: Bool
        var pronouns, hasKids, wantsKids, birthCountry: String
        var cannabis: String; var isCannabisFlexible: Bool
        var petTypes, petsName: String
        var isDrinksFlexible, isSmokingFlexible, isWorkoutFlexible, isSleepFlexible, isKidsFlexible: Bool
        var loveLanguage, zodiacSign: String
        var communicationStyle, conflictStyle: String
        var personalityType: String
        var interests, preferredDateActivities, wouldNotDoActivities: [String]
        var socialMediaLinks: [String]; var spotifyPlaylistURL: String
        var photoURLs: [String]
        var showLocation, showPersonalityTrait, showInterests: Bool
        var showLifestyle, showCareer, showPets: Bool

        init(from s: UserProfileStore) {
            bio = s.bio; jobTitle = s.jobTitle; school = s.school
            instagramHandle = s.instagramHandle; tiktokHandle = s.tiktokHandle
            orientation = s.orientation; showOrientation = s.showOrientation
            identity = s.identity; showIdentity = s.showIdentity
            pronouns = s.pronouns; hasKids = s.hasKids; wantsKids = s.wantsKids
            birthCountry = s.birthCountry
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
            socialMediaLinks = s.socialMediaLinks; spotifyPlaylistURL = s.spotifyPlaylistURL
            photoURLs = s.photoURLs
            showLocation = s.showLocation; showPersonalityTrait = s.showPersonalityTrait
            showInterests = s.showInterests; showLifestyle = s.showLifestyle
            showCareer = s.showCareer; showPets = s.showPets
        }

        func apply(to s: UserProfileStore) {
            s.bio = bio; s.jobTitle = jobTitle; s.school = school
            s.instagramHandle = instagramHandle; s.tiktokHandle = tiktokHandle
            s.orientation = orientation; s.showOrientation = showOrientation
            s.identity = identity; s.showIdentity = showIdentity
            s.pronouns = pronouns; s.hasKids = hasKids; s.wantsKids = wantsKids
            s.birthCountry = birthCountry
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
            s.socialMediaLinks = socialMediaLinks; s.spotifyPlaylistURL = spotifyPlaylistURL
            s.photoURLs = photoURLs
            s.showLocation = showLocation; s.showPersonalityTrait = showPersonalityTrait
            s.showInterests = showInterests; s.showLifestyle = showLifestyle
            s.showCareer = showCareer; s.showPets = showPets
        }
    }
}

// MARK: - Static Option Lists

extension UserProfileStore {
    static let communicationStyleOptions = ["Big Texter", "", "Phone Person"]
    static let conflictStyleOptions      = ["Quiet & Reserved", "", "Confrontational"]
    static let identityOptions = [
        "Man", "Woman", "Non-binary", "Gender fluid", "Gender queer",
        "Agender", "Bigender", "Two-spirit", "Transgender", "Prefer not to say"
    ]
    static let orientationOptions = [
        "Straight", "Gay", "Lesbian", "Bisexual",
        "Demisexual", "Pansexual", "Queer", "Questioning", "Prefer not to say"
    ]
    static let loveLanguageOptions = [
        "Words of Affirmation", "Acts of Service",
        "Receiving Gifts", "Quality Time", "Physical Touch"
    ]
    static let zodiacOptions = [
        "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
        "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"
    ]
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
    static let hasKidsOptions = ["Yes", "No"]
    static let wantsKidsOptions = ["Yes", "No", "Not for a while", "Maybe"]
    static let cannabisOptions = ["Never", "Sometimes", "Often"]
}
