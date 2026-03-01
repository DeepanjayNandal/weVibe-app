
import SwiftUI

struct SurveyStep2: View {
    
    @Environment(OnboardingRouter.self) private var onboardingRouter
    
    // Who to meet
    @State private var openToEveryone: Bool = true
    @State private var meetMen: Bool = false
    @State private var meetWomen: Bool = false
    
    // Age preference
    @State private var minAge: Double = 18
    @State private var maxAge: Double = 50
    
    // Distance
    @State private var distance: Double = 18
    
    // Relationship goals
    @State private var shortTerm: Bool = true
    @State private var longTerm: Bool = false
    @State private var marriage: Bool = false
    @State private var stillFiguringOut: Bool = true
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Progress Bar
                    ProgressBarView(current: 2, total: 5)
                    
                    // Who to meet
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Who would you like to meet ?")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))
                        
                        // Open to everyone toggle
                        HStack(spacing: 12) {
                            Toggle("", isOn: $openToEveryone)
                                .labelsHidden()
                                .tint(.green)
                            
                            Text("I'm open to dating everyone")
                                .foregroundStyle(.white)
                                .font(.system(size: 15))
                        }
                        
                        // Men / Women checkboxes
                        HStack(spacing: 32) {
                            GenderCheckbox(label: "Men", isSelected: $meetMen)
                            GenderCheckbox(label: "Women", isSelected: $meetWomen)
                        }
                        .opacity(openToEveryone ? 0.4 : 1.0)
                        .disabled(openToEveryone)
                        .padding(.horizontal, 40)
                    }
                    
                    // Age preference
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 2) {
                            Text("Age preference")
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .bold))
                            Text("*")
                                .foregroundStyle(.red)
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        HStack {
                            Text("\(Int(minAge))")
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                            Spacer()
                            Text("\(Int(maxAge))")
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                        }
                        
                        DualSlider(minValue: $minAge, maxValue: $maxAge, bounds: 18...80)
                    }
                    .padding(.top, 15)
                    
                    // Distance
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 2) {
                            Text("Distance")
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .bold))
                            Text("*")
                                .foregroundStyle(.red)
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        Text("\(Int(distance)) miles")
                            .foregroundStyle(.white)
                            .font(.system(size: 14))
                        
                        Slider(value: $distance, in: 1...100, step: 1)
                            .tint(.green)
                    }
                    .padding(.top, 15)
                    
                    // Relationship goals
                    VStack(alignment: .leading, spacing: 14) {
                        GoalCheckbox(label: "Short Term", isSelected: $shortTerm)
                        GoalCheckbox(label: "Long Term", isSelected: $longTerm)
                        GoalCheckbox(label: "Marriage", isSelected: $marriage)
                        GoalCheckbox(label: "Still figuring out", isSelected: $stillFiguringOut)
                    }
                    .padding(.top, 15)
                    
                    HStack(spacing: 40) {
                        Button {
                                onboardingRouter.pop()
                        } label: {
                            Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryBackground)
                                        .frame(width: 48, height: 48)
                                        .background(.white)
                                        .clipShape(Circle())
                        }
                        Spacer()
                        
                        Button {
                                onboardingRouter.navigate(to: .step3)
                        } label: {
                            Image(systemName: "chevron.right")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryBackground)
                                        .frame(width: 48, height: 48)
                                        .background(.white)
                                        .clipShape(Circle())
                        }
                    }
                    .padding(.top, 30)
                    
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


