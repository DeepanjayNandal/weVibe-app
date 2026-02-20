import SwiftUI 

struct PromptField: View {
    let label: String
    @Binding var text: String
    let suggestions: [String]
    @State private var showSuggestions: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main field
            Button {
                showSuggestions.toggle()
            } label: {
                HStack {
                    Text(text.isEmpty ? label : text)
                        .foregroundStyle(text.isEmpty ? .white.opacity(0.6) : .white)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: showSuggestions ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(.white.opacity(0.1))
                .cornerRadius(showSuggestions ? 0 : 14)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Suggestions dropdown
            if showSuggestions {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            text = suggestion
                            showSuggestions = false
                        } label: {
                            Text(suggestion)
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        
                        if suggestion != suggestions.last {
                            Divider()
                                .background(.white.opacity(0.2))
                        }
                    }
                }
                .background(.white.opacity(0.15))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}