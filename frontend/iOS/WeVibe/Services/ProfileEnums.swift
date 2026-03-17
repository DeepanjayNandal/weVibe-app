import Foundation

// MARK: - Gender

enum Gender: String, CaseIterable, Codable {
    case male           = "Male"
    case female         = "Female"
    case nonBinary      = "Non-binary"
    case preferNotToSay = "Prefer not to say"
}

// MARK: - Sexual Orientation

enum SexualOrientation: String, CaseIterable, Codable {
    case straight       = "Straight"
    case gay            = "Gay"
    case lesbian        = "Lesbian"
    case bisexual       = "Bisexual"
    case demisexual     = "Demisexual"
    case pansexual      = "Pansexual"
    case queer          = "Queer"
    case questioning    = "Questioning"
    case preferNotToSay = "Prefer not to say"
}

// MARK: - Gender Identity

enum GenderIdentity: String, CaseIterable, Codable {
    case man            = "Man"
    case woman          = "Woman"
    case nonBinary      = "Non-binary"
    case genderFluid    = "Gender fluid"
    case genderQueer    = "Gender queer"
    case agender        = "Agender"
    case bigender       = "Bigender"
    case twoSpirit      = "Two-spirit"
    case transgender    = "Transgender"
    case preferNotToSay = "Prefer not to say"
}

// MARK: - Frequency (drinks / smoking / workout / cannabis)

enum FrequencyHabit: String, CaseIterable, Codable {
    case never     = "Never"
    case sometimes = "Sometimes"
    case often     = "Often"
}

// MARK: - Sleep Schedule

enum SleepSchedule: String, CaseIterable, Codable {
    case nightOwl  = "Night Owl"
    case earlyBird = "Early Bird"
    case flexible  = "Flexible"
}

// MARK: - Pets / Children preference

enum FamilyPreference: String, CaseIterable, Codable {
    case dontWant = "Don't want"
    case unsure   = "Unsure"
    case want     = "Want"
    case have     = "Have"
}

// MARK: - Meet Preference

enum MeetPreference: String, CaseIterable, Codable {
    case men        = "Men"
    case women      = "Women"
    case openToBoth = "Open to both"
}

// MARK: - Relationship Goal

enum RelationshipGoal: String, CaseIterable, Codable {
    case shortTerm       = "Short Term"
    case longTerm        = "Long Term"
    case marriage        = "Marriage"
    case stillFiguringOut = "Still figuring out"
}

// MARK: - Love Language

enum LoveLanguage: String, CaseIterable, Codable {
    case wordsOfAffirmation = "Words of Affirmation"
    case actsOfService      = "Acts of Service"
    case receivingGifts     = "Receiving Gifts"
    case qualityTime        = "Quality Time"
    case physicalTouch      = "Physical Touch"
}

// MARK: - Zodiac Sign

enum ZodiacSign: String, CaseIterable, Codable {
    case aries       = "Aries"
    case taurus      = "Taurus"
    case gemini      = "Gemini"
    case cancer      = "Cancer"
    case leo         = "Leo"
    case virgo       = "Virgo"
    case libra       = "Libra"
    case scorpio     = "Scorpio"
    case sagittarius = "Sagittarius"
    case capricorn   = "Capricorn"
    case aquarius    = "Aquarius"
    case pisces      = "Pisces"
}

// MARK: - Career Field

enum CareerField: String, CaseIterable, Codable {
    case technology = "Technology"
    case healthcare = "Healthcare"
    case education  = "Education"
    case finance    = "Finance"
    case arts       = "Arts"
    case other      = "Other"
}

// MARK: - Education
// rawValue = what is sent to the backend (snake_case)
// displayName = what is shown in the UI picker

enum EducationLevel: String, CaseIterable, Codable {
    case highSchool = "high_school"
    case inCollege  = "in_college"
    case bachelors  = "bachelors"
    case masters    = "masters"
    case phd        = "phd"
    case other      = "other"

    var displayName: String {
        switch self {
        case .highSchool: return "High School"
        case .inCollege:  return "In College"
        case .bachelors:  return "Bachelor's Degree"
        case .masters:    return "Master's Degree"
        case .phd:        return "PhD / Doctorate"
        case .other:      return "Other"
        }
    }

    /// Convert a display name (from pickers) to the backend raw value.
    static func from(displayName: String) -> EducationLevel? {
        allCases.first { $0.displayName == displayName }
    }
}
