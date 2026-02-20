import SwiftUI

struct SurveyStep5: View {
    
    @Environment(Router.self) private var router
    
    @State private var prompt1: String = ""
    @State private var prompt2: String = ""
    @State private var prompt3: String = ""
    @State private var ownText: String = ""
    
    let prompts = [
        "I like the type of kind heart ",
        "The way to my heart is...",
        "I'm looking for someone who..."
    ]
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    ProgressBarView(current: 5, total: 5)
                    
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What makes you, you ?")
                            .foregroundStyle(.white)
                            .font(.system(size: 22, weight: .bold))
                        
                        Text("Add prompts")
                            .foregroundStyle(.white)
                            .font(.system(size: 14))
                    }
                    
                    
                    PromptField(label: "Prompt 1:", text: $prompt1, suggestions: prompts)
                    PromptField(label: "Prompt 2:", text: $prompt2, suggestions: prompts)
                    PromptField(label: "Prompt 3:", text: $prompt3, suggestions: prompts)
                    
                   
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Or write your own :")
                            .foregroundStyle(.white)
                            .font(.system(size: 14))
                        
                        ZStack(alignment: .topLeading) {
                            if ownText.isEmpty {
                                Text("Min 50 words")
                                    .foregroundStyle(.white.opacity(0.3))
                                    .font(.system(size: 15))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                            }
                            
                            TextEditor(text: $ownText)
                                .foregroundStyle(.white)
                                .font(.system(size: 15))
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(minHeight: 120)
                        }
                        .background(.white.opacity(0.1))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.top, 30)
                    
                   
                    HStack {
                        Button {
                            router.navigateSurveyStep4()
                        } label: {
                            Text("Previous step")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.primaryBackground)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(.white)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Button {
                        
                        } label: {
                            Text("Finish")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color(red: 0.1, green: 0.45, blue: 0.25))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 50)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
