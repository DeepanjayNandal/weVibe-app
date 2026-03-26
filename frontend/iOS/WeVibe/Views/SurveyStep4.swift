import SwiftUI

struct SurveyStep4: View {

    @Environment(OnboardingRouter.self) private var onboardingRouter
    @Environment(OnboardingData.self) private var onboardingData

    let educationOptions = EducationLevel.allCases.map(\.displayName)
    let careerOptions    = CareerField.allCases.map(\.rawValue)

    let languages = [
        "English", "Spanish", "Mandarin/Chinese", "Hindi", "Arabic",
        "French", "Portuguese", "Russian", "Japanese", "Korean",
        "German", "Vietnamese", "Italian", "Other+"
    ]

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    ProgressBarView(current: 4, total: 5)

                    // MARK: Education
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Education")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))

                        DropdownPicker(
                            placeholder: "Select your education level",
                            selection: Bindable(onboardingData).education,
                            options: educationOptions
                        )
                    }

                    // MARK: Career
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Career")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))

                        DropdownPicker(
                            placeholder: "Select your career field",
                            selection: Bindable(onboardingData).career,
                            options: careerOptions
                        )
                    }

                    // MARK: Height
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Height")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))

                        HStack(spacing: 10) {
                            // FT / CM toggle
                            HStack(spacing: 6) {
                                ForEach(["FT", "CM"], id: \.self) { unit in
                                    Button {
                                        guard unit != onboardingData.heightUnit else { return }
                                        onboardingData.heightUnit = unit
                                        if unit == "CM" {
                                            onboardingData.heightFt = ""
                                            onboardingData.heightIn = ""
                                        } else {
                                            onboardingData.heightCm = ""
                                        }
                                    } label: {
                                        Text(unit)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(onboardingData.heightUnit == unit ? .black : .white)
                                            .frame(width: 52, height: 48)
                                            .background(onboardingData.heightUnit == unit ? Color.green : .white.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if onboardingData.heightUnit == "FT" {
                                HeightDropdown(
                                    placeholder: "ft",
                                    selection: Bindable(onboardingData).heightFt,
                                    options: (3...8).map { String($0) },
                                    width: 75
                                )
                                Text("ft")
                                    .foregroundStyle(.white.opacity(0.6))
                                    .font(.system(size: 14))
                                HeightDropdown(
                                    placeholder: "in",
                                    selection: Bindable(onboardingData).heightIn,
                                    options: (0...11).map { String($0) },
                                    width: 75
                                )
                                Text("in")
                                    .foregroundStyle(.white.opacity(0.6))
                                    .font(.system(size: 14))
                            } else {
                                HeightDropdown(
                                    placeholder: "cm",
                                    selection: Bindable(onboardingData).heightCm,
                                    options: (91...272).map { String($0) },
                                    width: 90
                                )
                                Text("cm")
                                    .foregroundStyle(.white.opacity(0.6))
                                    .font(.system(size: 14))
                            }
                        }
                    }

                    // MARK: Languages
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Languages")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))

                        Text("Select as many as you'd like")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.system(size: 14))

                        FlowLayout(spacing: 10) {
                            ForEach(languages, id: \.self) { language in
                                Button {
                                    if onboardingData.languages.contains(language) {
                                        onboardingData.languages.remove(language)
                                    } else {
                                        onboardingData.languages.insert(language)
                                    }
                                } label: {
                                    Text(language)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(onboardingData.languages.contains(language) ? .black : .white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(onboardingData.languages.contains(language) ? Color.green : .clear)
                                        .cornerRadius(20)
                                        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // MARK: Navigation
                    HStack {
                        BackButton(style: .circle) {
                            onboardingData.save()
                            onboardingRouter.pop()
                        }

                        Spacer()

                        Button {
                            onboardingData.save()
                            onboardingRouter.navigate(to: .step5)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryBackground)
                                .frame(width: 48, height: 48)
                                .background(.white)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 16)

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

// MARK: - HeightDropdown

private struct HeightDropdown: View {
    let placeholder: String
    @Binding var selection: String
    let options: [String]
    let width: CGFloat

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
            }
        } label: {
            HStack {
                Text(selection.isEmpty ? placeholder : selection)
                    .foregroundStyle(selection.isEmpty ? .white.opacity(0.5) : .white)
                    .font(.system(size: 15))
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.white.opacity(0.4))
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 12)
            .frame(width: width, height: 48)
            .background(.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - DropdownPicker

private struct DropdownPicker: View {
    let placeholder: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
            }
        } label: {
            HStack {
                Text(selection.isEmpty ? placeholder : selection)
                    .foregroundStyle(selection.isEmpty ? .white.opacity(0.5) : .white)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(.white.opacity(0.1))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }
}
