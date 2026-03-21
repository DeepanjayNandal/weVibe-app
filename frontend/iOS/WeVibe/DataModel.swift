import SwiftUI

struct PersonalityQuestion {
    let question: String
    let options: [PersonalityOption]
}

struct PersonalityOption: Identifiable {
    let id: String
    let letter: String
    let text: String
}

struct PersonalityType {
    let mostly: any Numeric
    let type: String
}

struct PersonalityMeta {
   let type: String
   let emoji: String
   let color: Color
   let description: String
}
