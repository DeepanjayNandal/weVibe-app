import Foundation

// MARK: - ProfileDisplayData
// Flat, display-ready struct used by ProfileCardView for both own-profile and match-profile.

struct ProfileDisplayData {
    var displayName: String
    var age: Int
    var jobTitle: String
    var bio: String
    var pronouns: String
    var instagramHandle: String
    var tiktokHandle: String
    var locationDisplay: String
    var birthCountry: String
    var orientation: String
    var identity: String
    // personality test data

    var personalityType: String
    var personalityPrimary: String
    var personalitySecondary: String;  var isPersonalityTestComplete: Bool
    var loveLanguage: String
    var zodiacSign: String
    var communicationStyle: String
    var conflictStyle: String
    var interests: [String]
    var preferredDateActivities: [String]
    var wouldNotDoActivities: [String]
    var drinks: String;       var isDrinksFlexible: Bool
    var smoking: String;      var isSmokingFlexible: Bool
    var cannabis: String;     var isCannabisFlexible: Bool
    var workout: String;      var isWorkoutFlexible: Bool
    var sleepSchedule: String; var isSleepFlexible: Bool
    var pets: String
    var petTypes: String
    var petsName: String
    var children: String
    var ethnicities: [String]
    var languages: [String]
    var career: String
    var school: String
    var education: String
    var heightDisplay: String
    var photoURLs: [String]
    var prompts: [(question: String, answer: String)]
    var socialLinks: [String]
    var spotifyURL: String
    var sex: String
    var showSex: Bool
    var relationshipGoals: [String]
    var meetPreference: String
    var minAge: Int
    var maxAge: Int
    var distance: Double

    // Visibility flags (own profile = user's own settings; match = what they've shared)
    var showLocation: Bool
    var showOrientation: Bool
    var showPersonalityTrait: Bool
    var showInterests: Bool
    var showLifestyle: Bool
    var showCareer: Bool
    var showPets: Bool
    
}

// MARK: - Init from MatchProfile

extension ProfileDisplayData {
    init(from match: MatchProfile) {
        displayName          = match.fullName
        age                  = match.age
        jobTitle             = match.jobTitle
        bio                  = match.bio
        pronouns             = match.pronouns
        instagramHandle      = match.instagramHandle ?? ""
        tiktokHandle         = match.tiktokHandle ?? ""
        locationDisplay      = [match.locationCity, match.locationState].filter { !$0.isEmpty }.joined(separator: ", ")
        birthCountry         = ""
        orientation          = match.orientation ?? ""
        identity             = match.identity ?? ""
        isPersonalityTestComplete = false
        personalityType      = match.personalityType ?? ""
        personalityPrimary   = match.personalityPrimary ?? ""
        personalitySecondary = match.personalitySecondary ?? ""
        loveLanguage         = match.loveLanguage ?? ""
        zodiacSign           = match.zodiacSign ?? ""
        communicationStyle   = ""
        conflictStyle        = ""
        interests            = match.interests
        preferredDateActivities = match.preferredDateActivities
        wouldNotDoActivities = []
        drinks               = match.drinks;  isDrinksFlexible  = false
        smoking              = match.smoking; isSmokingFlexible = false
        cannabis             = match.cannabis; isCannabisFlexible = false
        workout              = match.workout; isWorkoutFlexible = false
        sleepSchedule        = match.sleepSchedule; isSleepFlexible = false
        pets                 = match.pets
        petTypes             = match.petTypes
        petsName             = ""
        children             = ""
        ethnicities          = match.ethnicities
        languages            = match.languages
        career               = match.career
        school               = match.school
        education            = match.education
        heightDisplay        = ""
        photoURLs            = match.photoURLs
        prompts              = match.prompts.map { ($0.question, $0.answer) }
        socialLinks          = match.socialMediaLinks
        spotifyURL           = ""
        sex                  = ""
        showSex              = true
        relationshipGoals    = []
        meetPreference       = ""
        minAge               = 18
        maxAge               = 50
        distance             = 25
        showLocation         = match.showLocation
        showOrientation      = match.showOrientation
        showPersonalityTrait = match.showPersonalityTrait
        showInterests        = match.showInterests
        showLifestyle        = match.showLifestyle
        showCareer           = match.showCareer
        showPets             = match.showPets
    }
}

// MARK: - ProfileCardSection & Mode

enum ProfileCardSection: String, CaseIterable, Identifiable {
    case photos
    case about, identity, personality, interests
    case dateActivities, lifestyle, background, career, prompts, preferences
    var id: Self { self }
}

enum ProfileCardMode {
    case ownProfile(onEdit: (ProfileCardSection) -> Void, onSettings: () -> Void)
    case matchProfile(onDismiss: () -> Void)
}
