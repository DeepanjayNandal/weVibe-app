import SwiftUI

struct SurveyStep2: View {

    @Environment(OnboardingRouter.self) private var onboardingRouter
    @Environment(OnboardingData.self) private var onboardingData

    @State private var showValidation = false

    let meetOptions = ["Men", "Women", "Open to both"]
    let goalOptions = ["Short Term", "Long Term", "Marriage", "Still figuring out"]

    private var isStep2Valid: Bool {
        !onboardingData.meetPreference.isEmpty && !onboardingData.relationshipGoals.isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    ProgressBarView(current: 2, total: 5)

                    // MARK: Who to meet
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 2) {
                            Text("Who would you like to meet?")
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .bold))
                            Text("*").foregroundStyle(.red).font(.system(size: 18, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(meetOptions, id: \.self) { option in
                                RadioButton(
                                    label: option,
                                    isSelected: onboardingData.meetPreference == option
                                ) {
                                    onboardingData.meetPreference = option
                                }
                            }
                        }

                        if showValidation && onboardingData.meetPreference.isEmpty {
                            ValidationError("Please select who you'd like to meet")
                        }
                    }

                    // MARK: Age preference
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Age Preference")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))

                        HStack {
                            Text("\(Int(onboardingData.minAge))")
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                            Spacer()
                            Text("\(Int(onboardingData.maxAge))")
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                        }

                        DualSlider(minValue: Bindable(onboardingData).minAge, maxValue: Bindable(onboardingData).maxAge, bounds: 18...80)
                    }
                    .padding(.top, 15)

                    // MARK: Distance
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Distance")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))

                        Text("\(Int(onboardingData.distance)) miles")
                            .foregroundStyle(.white)
                            .font(.system(size: 14))

                        Slider(value: Bindable(onboardingData).distance, in: 1...100, step: 1)
                            .tint(.green)
                    }
                    .padding(.top, 15)

                    // MARK: Relationship goals
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 2) {
                            Text("Relationship Goals")
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .bold))
                            Text("*").foregroundStyle(.red).font(.system(size: 18, weight: .bold))
                        }

                        Text("Select up to 2")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(goalOptions, id: \.self) { goal in
                                let isSelected = onboardingData.relationshipGoals.contains(goal)
                                let maxReached = onboardingData.relationshipGoals.count >= 2 && !isSelected

                                GoalCheckbox(label: goal, isSelected: isSelected) {
                                    if isSelected {
                                        onboardingData.relationshipGoals.remove(goal)
                                    } else if !maxReached {
                                        onboardingData.relationshipGoals.insert(goal)
                                    }
                                }
                                .opacity(maxReached ? 0.4 : 1.0)
                                .disabled(maxReached)
                            }
                        }

                        if showValidation && onboardingData.relationshipGoals.isEmpty {
                            ValidationError("Please select at least one relationship goal")
                        }
                    }
                    .padding(.top, 15)

                    // MARK: Navigation
                    HStack(spacing: 40) {
                        BackButton(style: .circle) {
                            onboardingData.save()
                            onboardingRouter.pop()
                        }

                        Spacer()

                        Button {
                            showValidation = true
                            if isStep2Valid {
                                onboardingData.save()
                                onboardingRouter.navigate(to: .step3)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isStep2Valid ? AppTheme.primaryBackground : .white.opacity(0.3))
                                .frame(width: 48, height: 48)
                                .background(isStep2Valid ? .white : .white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 30)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - RadioButton

private struct RadioButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(.green)
                            .frame(width: 14, height: 14)
                    }
                }
                Text(label)
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ValidationError: View {
    let message: String
    init(_ message: String) { self.message = message }
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 12))
        }
        .foregroundStyle(.red)
    }
}
