import SwiftUI

// All available prompts — shared across all three slots.
let allPrompts = [
    "The way to my heart is...",
    "I'm looking for someone who...",
    "My most controversial opinion...",
    "A life goal of mine...",
    "Two truths and a lie...",
    "I get way too excited about...",
    "My love language is...",
    "A fun fact about me...",
    "On weekends I...",
    "I recently discovered...",
    "I'm proudest of...",
    "My biggest pet peeve is...",
    "You should NOT date me if...",
    "I know the best spot in town for...",
    "The best way to ask me out is..."
]

/// A prompt slot: shows a picker button that opens a sheet, and an answer field once a prompt is selected.
struct PromptField: View {
    let label: String
    @Binding var question: String
    @Binding var answer: String
    /// Prompts already selected in the other two slots — shown greyed out.
    let usedByOthers: Set<String>

    @State private var showSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .foregroundStyle(.white.opacity(0.6))
                .font(.system(size: 14))

            // Picker trigger
            Button {
                showSheet = true
            } label: {
                HStack {
                    Text(question.isEmpty ? "Select a prompt..." : question)
                        .foregroundStyle(question.isEmpty ? .white.opacity(0.4) : .white)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.white.opacity(0.4))
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(.white.opacity(0.1))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSheet) {
                PromptPickerSheet(
                    selectedQuestion: $question,
                    usedByOthers: usedByOthers
                )
            }

            // Answer field — only shown once a prompt is selected
            if !question.isEmpty {
                TextField("Your answer...", text: $answer, axis: .vertical)
                    .foregroundStyle(.white)
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
                    .lineLimit(3...6)
            }
        }
    }
}

// MARK: - Prompt Picker Sheet

struct PromptPickerSheet: View {
    @Binding var selectedQuestion: String
    let usedByOthers: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()

                List {
                    ForEach(allPrompts, id: \.self) { prompt in
                        let disabled = usedByOthers.contains(prompt)
                        Button {
                            if !disabled {
                                selectedQuestion = prompt
                                dismiss()
                            }
                        } label: {
                            Text(prompt)
                                .foregroundStyle(disabled ? .white.opacity(0.3) : .white)
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .listRowBackground(AppTheme.primaryBackground)
                        .disabled(disabled)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Choose a Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
