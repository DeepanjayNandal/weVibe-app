

struct PersonalityQuestion {
    let question: String
    let options: [PersonalityOption]
}

struct PersonalityOption: Identifiable {
    let id: String
    let letter: String
    let text: String
}
