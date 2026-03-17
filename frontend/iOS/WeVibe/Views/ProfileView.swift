import SwiftUI
import FirebaseAuth

// MARK: - ProfileView (own profile tab)

struct ProfileView: View {
    @Environment(AuthManager.self)      private var authManager
    @Environment(OnboardingData.self)   private var onboarding
    @Environment(UserProfileStore.self) private var store

    @State private var activeEdit: ProfileCardSection?
    @State private var showSettingsSheet = false
    @State private var showLogoutConfirm = false

    // MARK: - Build display data from environments

    private var displayData: ProfileDisplayData {
        let name: String = {
            let stored = [store.firstName, store.lastName].filter { !$0.isEmpty }.joined(separator: " ")
            return stored.isEmpty ? (Auth.auth().currentUser?.displayName ?? "Your Name") : stored
        }()
        let age: Int = {
            guard let d = Int(onboarding.dobDay),
                  let y = Int(onboarding.dobYear) else { return 0 }
            let monthInt: Int? = Int(onboarding.dobMonth) ?? {
                let fmt = DateFormatter()
                fmt.dateFormat = "MMM"
                return fmt.date(from: onboarding.dobMonth).map {
                    Calendar.current.component(.month, from: $0)
                }
            }()
            guard let m = monthInt else { return 0 }
            let dob = Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
            return Calendar.current.dateComponents([.year], from: dob, to: .now).year ?? 0
        }()
        let height: String = {
            if store.heightUnit == "FT", !store.heightFt.isEmpty {
                return "\(store.heightFt)'\(store.heightIn.isEmpty ? "0" : store.heightIn)\""
            } else if !store.heightCm.isEmpty {
                return "\(store.heightCm) cm"
            }
            return ""
        }()
        let location = [onboarding.locationCity, onboarding.locationState]
            .filter { !$0.isEmpty }.joined(separator: ", ")
        let prompts: [(String, String)] = [
            (store.prompt1Question,      store.prompt1Answer),
            (store.prompt2Question,      store.prompt2Answer),
            (store.prompt3Question,      store.prompt3Answer),
            (store.customPromptQuestion, store.customPromptAnswer),
        ].filter { !$0.0.isEmpty }

        return ProfileDisplayData(
            displayName:             name,
            age:                     age,
            jobTitle:                store.jobTitle,
            bio:                     store.bio,
            pronouns:                store.pronouns,
            instagramHandle:         store.instagramHandle,
            tiktokHandle:            store.tiktokHandle,
            locationDisplay:         location,
            birthCountry:            store.birthCountry,
            orientation:             store.orientation,
            identity:                store.identity,
            personalityType:         store.personalityType,
            loveLanguage:            store.loveLanguage,
            zodiacSign:              store.zodiacSign,
            communicationStyle:      store.communicationStyle,
            conflictStyle:           store.conflictStyle,
            interests:               store.interests,
            preferredDateActivities: store.preferredDateActivities,
            wouldNotDoActivities:    store.wouldNotDoActivities,
            drinks:                  store.drinks,
            isDrinksFlexible:        store.isDrinksFlexible,
            smoking:                 store.smoking,
            isSmokingFlexible:       store.isSmokingFlexible,
            cannabis:                store.cannabis,
            isCannabisFlexible:      store.isCannabisFlexible,
            workout:                 store.workout,
            isWorkoutFlexible:       store.isWorkoutFlexible,
            sleepSchedule:           store.sleepSchedule,
            isSleepFlexible:         store.isSleepFlexible,
            pets:                    store.pets,
            petTypes:                store.petTypes,
            petsName:                store.petsName,
            children:                store.children,
            ethnicities:             store.ethnicities,
            languages:               store.languages,
            career:                  store.career,
            school:                  store.school,
            education:               store.education,
            heightDisplay:           height,
            photoURLs:               store.photoURLs,
            prompts:                 prompts,
            socialLinks:             store.socialMediaLinks,
            spotifyURL:              store.spotifyPlaylistURL,
            sex:                     onboarding.sex,
            showSex:                 store.showSex,
            relationshipGoals:       store.relationshipGoals.sorted(),
            meetPreference:          store.meetPreference,
            minAge:                  Int(store.minAge),
            maxAge:                  Int(store.maxAge),
            distance:                store.distance,
            showLocation:            store.showLocation,
            showOrientation:         store.showOrientation,
            showPersonalityTrait:    store.showPersonalityTrait,
            showInterests:           store.showInterests,
            showLifestyle:           store.showLifestyle,
            showCareer:              store.showCareer,
            showPets:                store.showPets
        )
    }

    // MARK: - Body

    var body: some View {
        ProfileCardView(
            data: displayData,
            mode: .ownProfile(
                onEdit:     { activeEdit = $0 },
                onSettings: { showSettingsSheet = true }
            )
        )
        .navigationBarHidden(true)
        .sheet(item: $activeEdit) { section in
            editSheet(for: section)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettingsSheet) {
            ProfileSettingsSheet(showLogoutConfirm: $showLogoutConfirm)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
        .alert("Log Out", isPresented: $showLogoutConfirm) {
            Button("Log Out", role: .destructive) { authManager.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out?")
        }
        .task {
            store.seedIfNeeded(from: onboarding)
            await store.fetchProfile()
        }
    }

    // MARK: - Edit Sheet Router

    @ViewBuilder func editSheet(for section: ProfileCardSection) -> some View {
        switch section {
        case .photos:         PhotosEditSheet()
        case .about:          AboutEditSheet()
        case .identity:       IdentityEditSheet()
        case .personality:    PersonalityEditSheet()
        case .interests:      InterestsEditSheet()
        case .dateActivities: DateActivitiesEditSheet()
        case .lifestyle:      LifestyleEditSheet()
        case .background:     BackgroundEditSheet()
        case .career:         CareerEditSheet()
        case .prompts:        PromptsEditSheet()
        case .preferences:    PreferencesEditSheet()
        }
    }
}

// MARK: - Settings Sheet

struct ProfileSettingsSheet: View {
    @Binding var showLogoutConfirm: Bool
    @AppStorage("profileCardLightTheme") private var isLightTheme: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()
                List {
                    Section("Appearance") {
                        HStack {
                            Label("Light Mode", systemImage: isLightTheme ? "sun.max.fill" : "moon.fill")
                                .foregroundStyle(.white)
                            Spacer()
                            Toggle("", isOn: $isLightTheme)
                                .tint(AppTheme.primaryButton)
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }

                    Section("Account") {
                        Label("Notification Settings", systemImage: "bell.fill")
                            .foregroundStyle(.white)
                            .listRowBackground(Color.white.opacity(0.06))
                        Label("Privacy Settings", systemImage: "lock.fill")
                            .foregroundStyle(.white)
                            .listRowBackground(Color.white.opacity(0.06))
                        Label("Help & Support", systemImage: "questionmark.circle.fill")
                            .foregroundStyle(.white)
                            .listRowBackground(Color.white.opacity(0.06))
                    }

                    Section {
                        Button(role: .destructive) {
                            dismiss()
                            showLogoutConfirm = true
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.secondaryBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.iconColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
