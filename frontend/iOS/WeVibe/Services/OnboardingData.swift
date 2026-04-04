import Foundation
import Observation

@Observable
final class OnboardingData {

    // MARK: - Step 1
    var dobDay: String = ""
    var dobMonth: String = ""
    var dobYear: String = ""
    var sex: String = ""
    var isSexHidden: Bool = false
    var ethnicities: Set<String> = []
    var locationCity: String = ""
    var locationState: String = ""
    var locationZip: String = ""
    var latitude: Double = 0
    var longitude: Double = 0

    // MARK: - Step 2
    var meetPreference: String = ""      // "Men", "Women", "Open to both"
    var minAge: Double = 18
    var maxAge: Double = 50
    var distance: Double = 18
    var relationshipGoals: Set<String> = []

    // MARK: - Step 3
    var drinks: String = ""
    var smoking: String = ""
    var pets: String = ""
    var children: String = ""
    var workout: String = ""
    var sleepSchedule: String = ""

    // MARK: - Step 4
    var education: String = ""
    var career: String = ""
    var heightFt: String = ""
    var heightIn: String = ""
    var heightCm: String = ""
    var heightUnit: String = "FT"
    var languages: Set<String> = []

    // MARK: - Step 5
    var prompt1Question: String = ""
    var prompt1Answer: String = ""
    var prompt2Question: String = ""
    var prompt2Answer: String = ""
    var prompt3Question: String = ""
    var prompt3Answer: String = ""
    var ownPrompt: String = ""
    var ownPromptAnswer: String = ""

    // MARK: - Persistence
    // Draft is stored as a file with .completeFileProtection — encrypted on disk when device is locked.
    // This protects DOB, location, and other sensitive fields from access on jailbroken devices.

    private static var draftURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("onboarding_draft.json")
    }

    init() {
        load()
    }

    func save() {
        let draft = Draft(
            dobDay: dobDay, dobMonth: dobMonth, dobYear: dobYear,
            sex: sex, isSexHidden: isSexHidden,
            ethnicities: Array(ethnicities),
            locationCity: locationCity, locationState: locationState, locationZip: locationZip,
            latitude: latitude, longitude: longitude,
            meetPreference: meetPreference, minAge: minAge, maxAge: maxAge, distance: distance,
            relationshipGoals: Array(relationshipGoals),
            drinks: drinks, smoking: smoking, pets: pets, children: children,
            workout: workout, sleepSchedule: sleepSchedule,
            education: education, career: career,
            heightFt: heightFt, heightIn: heightIn, heightCm: heightCm, heightUnit: heightUnit,
            languages: Array(languages),
            prompt1Question: prompt1Question, prompt1Answer: prompt1Answer,
            prompt2Question: prompt2Question, prompt2Answer: prompt2Answer,
            prompt3Question: prompt3Question, prompt3Answer: prompt3Answer,
            ownPrompt: ownPrompt,
            ownPromptAnswer: ownPromptAnswer
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        let url = Self.draftURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func clear() {
        try? FileManager.default.removeItem(at: Self.draftURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.draftURL),
              let draft = try? JSONDecoder().decode(Draft.self, from: data) else { return }
        dobDay = draft.dobDay
        dobMonth = draft.dobMonth
        dobYear = draft.dobYear
        sex = draft.sex
        isSexHidden = draft.isSexHidden
        ethnicities = Set(draft.ethnicities)
        locationCity = draft.locationCity
        locationState = draft.locationState
        locationZip = draft.locationZip
        latitude = draft.latitude; longitude = draft.longitude
        meetPreference = draft.meetPreference
        minAge = draft.minAge; maxAge = draft.maxAge; distance = draft.distance
        relationshipGoals = Set(draft.relationshipGoals)
        drinks = draft.drinks; smoking = draft.smoking; pets = draft.pets; children = draft.children
        workout = draft.workout; sleepSchedule = draft.sleepSchedule
        education = draft.education; career = draft.career
        heightFt = draft.heightFt; heightIn = draft.heightIn; heightCm = draft.heightCm; heightUnit = draft.heightUnit
        languages = Set(draft.languages)
        prompt1Question = draft.prompt1Question; prompt1Answer = draft.prompt1Answer
        prompt2Question = draft.prompt2Question; prompt2Answer = draft.prompt2Answer
        prompt3Question = draft.prompt3Question; prompt3Answer = draft.prompt3Answer
        ownPrompt = draft.ownPrompt
        ownPromptAnswer = draft.ownPromptAnswer
    }

    // MARK: - Codable mirror

    private struct Draft: Codable {
        var dobDay, dobMonth, dobYear: String
        var sex: String; var isSexHidden: Bool
        var ethnicities: [String]
        var locationCity, locationState, locationZip: String
        var latitude, longitude: Double
        var meetPreference: String
        var minAge, maxAge, distance: Double
        var relationshipGoals: [String]
        var drinks, smoking, pets, children, workout, sleepSchedule: String
        var education, career: String
        var heightFt, heightIn, heightCm, heightUnit: String
        var languages: [String]
        var prompt1Question, prompt1Answer: String
        var prompt2Question, prompt2Answer: String
        var prompt3Question, prompt3Answer: String
        var ownPrompt: String
        var ownPromptAnswer: String
    }
}
