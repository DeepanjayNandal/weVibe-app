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
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false

    // MARK: - Build display data from environments

    private var displayData: ProfileDisplayData {
        let name: String = {
            let stored = [store.firstName, store.lastName].filter { !$0.isEmpty }.joined(separator: " ")
            return stored.isEmpty ? (Auth.auth().currentUser?.displayName ?? "Your Name") : stored
        }()
        let age: Int = {
            // Prefer ISO date from backend; fall back to onboarding components on first launch
            if !store.birthDate.isEmpty {
                let dob: Date? = {
                    // Try full ISO 8601 first (e.g. "1997-07-14T00:00:00.000Z" from backend)
                    let iso = ISO8601DateFormatter()
                    if let d = iso.date(from: store.birthDate) { return d }
                    // Fallback: plain date string "yyyy-MM-dd"
                    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                    return fmt.date(from: store.birthDate)
                }()
                if let dob {
                    return Calendar.current.dateComponents([.year], from: dob, to: .now).year ?? 0
                }
            }
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
        let location = [
            store.locationCity.isEmpty  ? onboarding.locationCity  : store.locationCity,
            store.locationState.isEmpty ? onboarding.locationState : store.locationState,
        ].filter { !$0.isEmpty }.joined(separator: ", ")
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
            personalityPrimary:      store.personalityPrimary,
            personalitySecondary:    store.personalitySecondary,
            isPersonalityTestComplete: store.isPersonalityTestComplete,
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
            photoURLs:               store.photos.map(\.url),
            prompts:                 prompts,
            socialLinks:             store.socialMediaLinks,
            spotifyURL:              store.spotifyPlaylistURL,
            sex:                     store.sex.isEmpty ? onboarding.sex : store.sex,
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
        ZStack(alignment: .top) {
            ProfileCardView(
                data: displayData,
                mode: .ownProfile(
                    onEdit:     { activeEdit = $0 },
                    onSettings: { showSettingsSheet = true }
                )
            )
            .refreshable { await store.fetchProfile() }
            if store.loadState.isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.4)
            }
            if store.loadState.isFailed && store.firstName.isEmpty {
                // First load failed with no cached data — show a full recovery screen
                // rather than an empty profile with a small banner.
                ErrorStateView(
                    title: "Couldn't load your profile",
                    message: store.loadState.failureMessage ?? "Check your connection and try again."
                ) {
                    Task { await store.fetchProfile() }
                }
                .transition(.opacity)
            } else if store.loadState.isFailed {
                Label("Couldn't refresh. Pull down to try again.", systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.7), in: Capsule())
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.loadState.isFailed)
        .navigationBarHidden(true)
        .sheet(item: $activeEdit) { section in
            editSheet(for: section)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettingsSheet) {
            ProfileSettingsSheet(showLogoutConfirm: $showLogoutConfirm, showDeleteConfirm: $showDeleteConfirm)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
        .alert("Log Out", isPresented: $showLogoutConfirm) {
            Button("Log Out", role: .destructive) { authManager.logout(profileStore: store, onboardingData: onboarding) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out?")
        }
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Delete Account", role: .destructive) {
                isDeletingAccount = true
                Task {
                    await authManager.deleteAccount(profileStore: store, onboardingData: onboarding)
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your account will be scheduled for permanent deletion in 30 days. You can cancel by logging back in within that period.\n\nThis action cannot be undone after 30 days.")
        }
        .alert("Save Failed", isPresented: Binding(
            get: { store.patchError != nil },
            set: { if !$0 { store.patchError = nil } }
        )) {
            Button("OK") { store.patchError = nil }
        } message: {
            Text(store.patchError ?? "")
        }
        .task {
            await store.fetchProfile()
        }
        .onChange(of: store.sessionExpired) { _, expired in
            guard expired else { return }
            // Token was rejected by the backend — force sign-out so the user re-authenticates.
            authManager.logout(profileStore: store, onboardingData: onboarding)
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
    @Binding var showDeleteConfirm: Bool
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

                        Button(role: .destructive) {
                            dismiss()
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
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
