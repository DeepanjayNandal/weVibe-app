import Foundation
import Observation

@Observable
final class PersonalityTestData {

    var answers: [Int?] = Array(repeating: nil, count: StaticConfig.personalityQuestions.count)

    var primaryType: String      = ""
    var secondaryType: String    = ""
    var isHybrid: Bool           = false
    var showTraitOnProfile: Bool = true


    var isComplete: Bool {
        answers.allSatisfy { $0 != nil }
    }

    var completedAnswers: [Int] {
        answers.compactMap { $0 }
    }

    var result: PersonalityResult {
        calculatePersonalityResult(from: completedAnswers)
    }


    private static let storageKey = "wevibe_personality_draft"

    init() {
        load()
    }

    
    func selectAnswer(_ answerIndex: Int, forQuestion questionIndex: Int) {
        guard questionIndex < answers.count else { return }
        answers[questionIndex] = answerIndex
        save()
    }

    
    func commitResult(_ result: PersonalityResult) {
        primaryType   = result.primary.type
        secondaryType = result.secondary?.type ?? ""
        isHybrid      = result.isHybrid
        save()
    }

    
    func reset() {
        answers       = Array(repeating: nil, count: StaticConfig.personalityQuestions.count)
        primaryType   = ""
        secondaryType = ""
        isHybrid      = false
        showTraitOnProfile = true
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }


    func save() {
        let draft = Draft(
            answers:            answers,
            primaryType:        primaryType,
            secondaryType:      secondaryType,
            isHybrid:           isHybrid,
            showTraitOnProfile: showTraitOnProfile
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        guard
            let data  = UserDefaults.standard.data(forKey: Self.storageKey),
            let draft = try? JSONDecoder().decode(Draft.self, from: data)
        else { return }

        answers            = draft.answers
        primaryType        = draft.primaryType
        secondaryType      = draft.secondaryType
        isHybrid           = draft.isHybrid
        showTraitOnProfile = draft.showTraitOnProfile
        
    }


    private struct Draft: Codable {
        var answers:            [Int?]
        var primaryType:        String
        var secondaryType:      String
        var isHybrid:           Bool
        var showTraitOnProfile: Bool
    }
}
