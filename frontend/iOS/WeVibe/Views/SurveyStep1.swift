import SwiftUI

struct SurveyStep1: View {

    @Environment(OnboardingRouter.self) private var onboardingRouter
    @Environment(OnboardingData.self) private var onboardingData
    @EnvironmentObject private var locationManager: LocationManager

    @State private var showValidation = false

    let sexOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    let ethnicities = ["White", "Asian", "Other+", "Hispanic/Latino", "Black/African American", "Native Hawaiian", "Pacific Islander"]

    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    var years: [String] {
        let maxYear = Calendar.current.component(.year, from: Date()) - 18
        return (1930...maxYear).reversed().map { String($0) }
    }
    var days: [String] {
        let monthIndex = months.firstIndex(of: onboardingData.dobMonth).map { $0 + 1 }
        let year = Int(onboardingData.dobYear) ?? 2000
        var components = DateComponents()
        components.month = monthIndex ?? 1
        components.year = year
        let range = Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: components) ?? Date())
        let count = range?.count ?? 31
        return (1...count).map { String($0) }
    }

    // MARK: - Validation

    private var dobFilled: Bool {
        !onboardingData.dobDay.isEmpty && !onboardingData.dobMonth.isEmpty && !onboardingData.dobYear.isEmpty
    }

    private var age18OrOlder: Bool {
        guard let day = Int(onboardingData.dobDay),
              let year = Int(onboardingData.dobYear),
              year > 1900 else { return false }
        let monthIndex = months.firstIndex(of: onboardingData.dobMonth).map { $0 + 1 } ?? 0
        guard monthIndex > 0 else { return false }
        var components = DateComponents()
        components.day = day; components.month = monthIndex; components.year = year
        guard let dob = Calendar.current.date(from: components) else { return false }
        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        return age >= 18
    }

    private var dobError: String? {
        guard showValidation else { return nil }
        if !dobFilled { return "Please enter your date of birth" }
        if !age18OrOlder { return "You must be at least 18 years old" }
        return nil
    }

    private var sexError: String? {
        guard showValidation, onboardingData.sex.isEmpty else { return nil }
        return "Please select your sex"
    }

    private var locationError: String? {
        guard showValidation, onboardingData.locationCity.isEmpty else { return nil }
        return "Location is required to find you matches"
    }

    private var isStep1Valid: Bool {
        dobFilled && age18OrOlder && !onboardingData.sex.isEmpty && !onboardingData.locationCity.isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    Button("Back", systemImage: "arrow.left") {
                        onboardingData.save()
                        onboardingRouter.pop()
                    }.labelStyle(.iconOnly)

                    ProgressBarView(current: 1, total: 5)

                    // MARK: Date of Birth
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Date of Birth", required: true)

                        HStack(alignment: .center, spacing: 12) {
                            // Day — dropdown
                            Menu {
                                ForEach(days, id: \.self) { d in
                                    Button(d) { onboardingData.dobDay = d }
                                }
                            } label: {
                                HStack {
                                    Text(onboardingData.dobDay.isEmpty ? "DD" : onboardingData.dobDay)
                                        .foregroundStyle(onboardingData.dobDay.isEmpty ? .white.opacity(0.5) : .white)
                                        .font(.system(size: 15))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(.white.opacity(0.4))
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 12)
                                .frame(width: 85, height: 48)
                                .background(.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(showValidation && onboardingData.dobDay.isEmpty ? Color.red.opacity(0.7) : .white.opacity(0.3), lineWidth: 1)
                                )
                            }

                            // Month — dropdown
                            Menu {
                                ForEach(months, id: \.self) { m in
                                    Button(m) { onboardingData.dobMonth = m }
                                }
                            } label: {
                                HStack {
                                    Text(onboardingData.dobMonth.isEmpty ? "Month" : onboardingData.dobMonth)
                                        .foregroundStyle(onboardingData.dobMonth.isEmpty ? .white.opacity(0.5) : .white)
                                        .font(.system(size: 15))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(.white.opacity(0.4))
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 12)
                                .frame(width: 105, height: 48)
                                .background(.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(showValidation && onboardingData.dobMonth.isEmpty ? Color.red.opacity(0.7) : .white.opacity(0.3), lineWidth: 1)
                                )
                            }

                            // Year — dropdown
                            Menu {
                                ForEach(years, id: \.self) { y in
                                    Button(y) { onboardingData.dobYear = y }
                                }
                            } label: {
                                HStack {
                                    Text(onboardingData.dobYear.isEmpty ? "Year" : onboardingData.dobYear)
                                        .foregroundStyle(onboardingData.dobYear.isEmpty ? .white.opacity(0.5) : .white)
                                        .font(.system(size: 15))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(.white.opacity(0.4))
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 12)
                                .frame(width: 110, height: 48)
                                .background(.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(showValidation && onboardingData.dobYear.isEmpty ? Color.red.opacity(0.7) : .white.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }

                        if let error = dobError {
                            ValidationError(error)
                        }
                    }

                    // MARK: Sex
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle("What is your sex?", required: true)

                        Menu {
                            ForEach(sexOptions, id: \.self) { option in
                                Button(option) { onboardingData.sex = option }
                            }
                        } label: {
                            HStack {
                                Text(onboardingData.sex.isEmpty ? "Select" : onboardingData.sex)
                                    .foregroundStyle(onboardingData.sex.isEmpty ? .white.opacity(0.5) : .white)
                                    .font(.system(size: 16))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.white.opacity(0.5))
                                    .font(.system(size: 13))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(.white.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(showValidation && onboardingData.sex.isEmpty ? Color.red.opacity(0.7) : .white.opacity(0.3), lineWidth: 1)
                            )
                        }

                        if let error = sexError {
                            ValidationError(error)
                        }

                        // Hidden from profile label
                        Button {
                            onboardingData.isSexHidden.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: onboardingData.isSexHidden ? "eye.slash" : "eye")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(onboardingData.isSexHidden ? "Hidden from profile" : "Visible on profile")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: Ethnicity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's your ethnicity?")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))

                        Text("Select as many as you'd like")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.system(size: 14))

                        FlowLayout(spacing: 10) {
                            ForEach(ethnicities, id: \.self) { ethnicity in
                                EthnicityChip(
                                    label: ethnicity,
                                    isSelected: onboardingData.ethnicities.contains(ethnicity)
                                ) {
                                    if onboardingData.ethnicities.contains(ethnicity) {
                                        onboardingData.ethnicities.remove(ethnicity)
                                    } else {
                                        onboardingData.ethnicities.insert(ethnicity)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Location
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Where are you located?", required: true)

                        locationCard

                        if let error = locationError {
                            ValidationError(error)
                        }
                    }

                    // Next button
                    HStack {
                        Spacer()
                        Button {
                            showValidation = true
                            if isStep1Valid {
                                onboardingData.save()
                                onboardingRouter.navigate(to: .step2)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isStep1Valid ? AppTheme.primaryBackground : .white.opacity(0.3))
                                .frame(width: 48, height: 48)
                                .background(isStep1Valid ? .white : .white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 40)

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
        .onAppear {
            if locationManager.authStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.authStatus == .authorizedWhenInUse || locationManager.authStatus == .authorizedAlways {
                // Always fetch fresh location — covers first visit and re-entry after logout.
                locationManager.refreshLocation()
            }
        }
        .onChange(of: locationManager.city) { _, city in
            onboardingData.locationCity = city
            onboardingData.locationState = locationManager.state
            onboardingData.locationZip = locationManager.zip
            onboardingData.latitude = locationManager.latitude
            onboardingData.longitude = locationManager.longitude
        }
        .onChange(of: onboardingData.dobMonth) { _, _ in
            if !onboardingData.dobDay.isEmpty && !days.contains(onboardingData.dobDay) {
                onboardingData.dobDay = ""
            }
        }
        .onChange(of: onboardingData.dobYear) { _, _ in
            if !onboardingData.dobDay.isEmpty && !days.contains(onboardingData.dobDay) {
                onboardingData.dobDay = ""
            }
        }
    }

    // MARK: - Location Card

    @ViewBuilder
    private var locationCard: some View {
        let hasLocation = !onboardingData.locationCity.isEmpty

        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundStyle(hasLocation ? AppTheme.primaryButton : .white.opacity(0.4))
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                if hasLocation {
                    Text("\(onboardingData.locationCity), \(onboardingData.locationState)")
                        .foregroundStyle(.white)
                        .font(.system(size: 15, weight: .medium))
                    Text(onboardingData.locationZip)
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.system(size: 13))
                } else {
                    Text(locationManager.isLoading ? "Fetching location..." : "Location not available")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.system(size: 15))
                }
            }

            Spacer()

            Button {
                locationManager.refreshLocation()
            } label: {
                Text("Refresh")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(hasLocation ? AppTheme.primaryButton.opacity(0.15) : .white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    showValidation && !hasLocation ? Color.red.opacity(0.7) : (hasLocation ? AppTheme.primaryButton.opacity(0.5) : .white.opacity(0.2)),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Helpers

extension View {
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let required: Bool

    init(_ title: String, required: Bool = false) {
        self.title = title
        self.required = required
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .foregroundStyle(.white)
                .font(.system(size: 18, weight: .bold))
            if required {
                Text("*").foregroundStyle(.red).font(.system(size: 18, weight: .bold))
            }
        }
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
