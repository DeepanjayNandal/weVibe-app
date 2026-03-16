import SwiftUI
import PhotosUI

// MARK: - Photos Edit Sheet

struct PhotosEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var urls: [String] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []

    private static let maxPhotos = 6
    private var remaining: Int { Swift.max(0, Self.maxPhotos - urls.count - newImages.count) }
    private var total: Int { urls.count + newImages.count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        infoNote("Up to \(Self.maxPhotos) photos. Tap and hold to reorder. Photos are stored in the cloud.")

                        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: columns, spacing: 10) {
                            // Existing URL photos
                            ForEach(urls.indices, id: \.self) { i in
                                photoCell {
                                    AsyncImage(url: URL(string: urls[i])) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        AppTheme.secondaryBackground
                                    }
                                } onRemove: {
                                    urls.remove(at: i)
                                }
                            }
                            // Newly picked local images
                            ForEach(newImages.indices, id: \.self) { i in
                                photoCell {
                                    Image(uiImage: newImages[i])
                                        .resizable().scaledToFill()
                                } onRemove: {
                                    newImages.remove(at: i)
                                    if i < pickerItems.count { pickerItems.remove(at: i) }
                                }
                            }
                            // Add slot(s)
                            if total < Self.maxPhotos {
                                PhotosPicker(
                                    selection: $pickerItems,
                                    maxSelectionCount: remaining,
                                    matching: .images
                                ) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 24, weight: .light))
                                            .foregroundStyle(AppTheme.iconColor)
                                        Text("\(remaining) left")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.white.opacity(0.05))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        .foregroundStyle(AppTheme.iconColor.opacity(0.4)))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Photos (\(total)/\(Self.maxPhotos))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.secondaryBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .foregroundStyle(AppTheme.iconColor).fontWeight(.semibold)
                }
            }
            .onChange(of: pickerItems) { loadNewImages() }
        }
        .onAppear { urls = store.photoURLs }
    }

    @ViewBuilder
    private func photoCell<Content: View>(
        @ViewBuilder image: () -> Content,
        onRemove: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            image()
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()
                .cornerRadius(12)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.5), in: Circle())
            }
            .padding(6)
        }
    }

    private func loadNewImages() {
        newImages = []
        for item in pickerItems {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data, let img = UIImage(data: data) {
                    DispatchQueue.main.async { newImages.append(img) }
                }
            }
        }
    }

    private func save() {
        // Existing URLs kept as-is; new local images would be uploaded here in production.
        // For now only URL removals are persisted.
        store.photoURLs = urls
        Task { await store.patchProfile() }
        dismiss()
    }
}

// MARK: - About Edit Sheet

struct AboutEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var bio = ""
    @State private var instagram = ""
    @State private var tiktok = ""
    @State private var spotify = ""
    @State private var showValidation = false

    var body: some View {
        editNav(title: "About Me", onSave: save) {
            sectionLabel("Name")
            requiredLabel("First Name")
            editField("", "First name", text: $firstName)
            if showValidation && firstName.trimmingCharacters(in: .whitespaces).isEmpty {
                validationError("First name is required")
            }
            requiredLabel("Last Name")
            editField("", "Last name", text: $lastName)
            if showValidation && lastName.trimmingCharacters(in: .whitespaces).isEmpty {
                validationError("Last name is required")
            }
            sectionLabel("Bio")
            editField("", "Tell people about yourself...", text: $bio, multiline: true)
            sectionLabel("Social")
            handleField("Instagram", text: $instagram, maxLength: 30)
            handleField("TikTok",    text: $tiktok,    maxLength: 24)
            editField("Spotify / Apple Music Playlist", "https://open.spotify.com/playlist/...", text: $spotify, keyboardType: .URL)
        }
        .onAppear {
            firstName = store.firstName
            lastName  = store.lastName
            bio       = store.bio
            instagram = store.instagramHandle
            tiktok    = store.tiktokHandle
            spotify   = store.spotifyPlaylistURL
        }
    }

    private func save() {
        let fn = firstName.trimmingCharacters(in: .whitespaces)
        let ln = lastName.trimmingCharacters(in: .whitespaces)
        guard !fn.isEmpty && !ln.isEmpty else { showValidation = true; return }
        store.firstName          = fn
        store.lastName           = ln
        store.bio                = bio
        store.instagramHandle    = instagram
        store.tiktokHandle       = tiktok
        store.spotifyPlaylistURL = spotify
        Task { await store.patchProfile() }; dismiss()
    }
}


// MARK: - Identity Edit Sheet

struct IdentityEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var orientation = ""
    @State private var showOrientation = true
    @State private var identity = ""
    @State private var showIdentity = true
    @State private var pronouns = ""
    @State private var showSex = true

    var body: some View {
        editNav(title: "Identity", onSave: save) {
            sectionLabel("Gender")
            toggleRow("Show gender on my profile", isOn: $showSex)
            editField("Pronouns", "e.g. she/her, he/him, they/them", text: $pronouns)
            pickerRow("Sexual Orientation", selection: $orientation, options: UserProfileStore.orientationOptions)
            toggleRow("Show orientation on my profile", isOn: $showOrientation)
            pickerRow("Gender Identity", selection: $identity, options: UserProfileStore.identityOptions)
            toggleRow("Show identity on my profile", isOn: $showIdentity)
        }
        .onAppear {
            orientation = store.orientation; showOrientation = store.showOrientation
            identity = store.identity; showIdentity = store.showIdentity
            pronouns = store.pronouns; showSex = store.showSex
        }
    }

    private func save() {
        store.orientation = orientation; store.showOrientation = showOrientation
        store.identity = identity; store.showIdentity = showIdentity
        store.pronouns = pronouns; store.showSex = showSex
        Task { await store.patchProfile() }; dismiss()
    }
}

// MARK: - Personality Edit Sheet

struct PersonalityEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var loveLanguage = ""
    @State private var zodiac = ""
    @State private var comm = ""
    @State private var conflict = ""

    var body: some View {
        editNav(title: "Personality", onSave: save) {
            pickerRow("Love Language", selection: $loveLanguage, options: UserProfileStore.loveLanguageOptions)
            pickerRow("Zodiac Sign", selection: $zodiac, options: UserProfileStore.zodiacOptions)
            BinarySlider(title: "Communication Style", options: UserProfileStore.communicationStyleOptions,
                         selection: $comm)
            BinarySlider(title: "Conflict Style", options: UserProfileStore.conflictStyleOptions,
                         selection: $conflict)
        }
        .onAppear {
            loveLanguage = store.loveLanguage
            zodiac = store.zodiacSign; comm = store.communicationStyle; conflict = store.conflictStyle
        }
    }

    private func save() {
        store.loveLanguage = loveLanguage
        store.zodiacSign = zodiac; store.communicationStyle = comm; store.conflictStyle = conflict
        Task { await store.patchProfile() }; dismiss()
    }
}

// MARK: - Interests Edit Sheet

struct InterestsEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var searchText = ""

    private static let maxInterests = 7

    private var filtered: [String] {
        searchText.isEmpty ? UserProfileStore.interestOptions
            : UserProfileStore.interestOptions.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !selected.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionLabel("Selected (\(selected.count)/\(Self.maxInterests))")
                                FlowLayout(spacing: 8) {
                                    ForEach(Array(selected).sorted(), id: \.self) { interest in
                                        chipToggle(interest, isSelected: true)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            Divider().overlay(Color.white.opacity(0.08)).padding(.horizontal, 16)
                        }
                        sectionLabel("All Interests").padding(.horizontal, 16)
                        FlowLayout(spacing: 8) {
                            ForEach(filtered, id: \.self) { interest in
                                chipToggle(interest, isSelected: selected.contains(interest))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            }
            .searchable(text: $searchText, prompt: "Search interests")
            .navigationTitle("Interests & Hobbies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.secondaryBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.foregroundStyle(AppTheme.iconColor).fontWeight(.semibold)
                }
            }
        }
        .onAppear { selected = Set(store.interests) }
    }

    @ViewBuilder private func chipToggle(_ text: String, isSelected: Bool) -> some View {
        let atMax = selected.count >= Self.maxInterests && !isSelected
        Button {
            if isSelected { selected.remove(text) }
            else if !atMax { selected.insert(text) }
        } label: {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? AppTheme.iconColor : atMax ? .white.opacity(0.2) : .white.opacity(0.7))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? AppTheme.iconColor.opacity(0.15) : Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? AppTheme.iconColor.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1))
                .clipShape(Capsule())
        }
        .disabled(atMax)
    }

    private func save() {
        store.interests = Array(selected).sorted()
        Task { await store.patchProfile() }; dismiss()
    }
}

// MARK: - Date Activities Edit Sheet

struct DateActivitiesEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var wouldDo: Set<String> = []
    @State private var wouldNot: Set<String> = []

    private static let maxActivities = 3

    var body: some View {
        editNav(title: "Date Activities", onSave: save) {
            activitiesSection("Would love to do on a date (\(wouldDo.count)/\(Self.maxActivities))",
                              selected: $wouldDo, blocked: wouldNot, accent: AppTheme.iconColor)
            activitiesSection("Would NOT do on a date (\(wouldNot.count)/\(Self.maxActivities))",
                              selected: $wouldNot, blocked: wouldDo, accent: Color(hex: "#C0392B"))
        }
        .onAppear { wouldDo = Set(store.preferredDateActivities); wouldNot = Set(store.wouldNotDoActivities) }
    }

    @ViewBuilder private func activitiesSection(
        _ title: String, selected: Binding<Set<String>>, blocked: Set<String>, accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
            FlowLayout(spacing: 8) {
                ForEach(UserProfileStore.dateActivityOptions, id: \.self) { act in
                    let on = selected.wrappedValue.contains(act)
                    let atMax = selected.wrappedValue.count >= Self.maxActivities && !on
                    let off = blocked.contains(act) || atMax
                    Button {
                        guard !blocked.contains(act) else { return }
                        if on { selected.wrappedValue.remove(act) }
                        else if !atMax { selected.wrappedValue.insert(act) }
                    } label: {
                        Text(act)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(on ? accent : off ? .white.opacity(0.2) : .white.opacity(0.7))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(on ? accent.opacity(0.2) : Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 20)
                                .stroke(on ? accent.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
                            .clipShape(Capsule())
                    }.disabled(off)
                }
            }
        }
    }

    private func save() {
        store.preferredDateActivities = Array(wouldDo).sorted()
        store.wouldNotDoActivities = Array(wouldNot).sorted()
        Task { await store.patchProfile() }; dismiss()
    }
}

// MARK: - Lifestyle Edit Sheet

struct LifestyleEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var drinks = ""
    @State private var smoking = ""
    @State private var workout = ""
    @State private var sleepSchedule = ""
    @State private var pets = ""
    @State private var cannabis = ""
    @State private var children = ""
    @State private var petTypes = ""
    @State private var petsName = ""
    @State private var isDrinksFlexible = false
    @State private var isSmokingFlexible = false
    @State private var isWorkoutFlexible = false
    @State private var isSleepFlexible = false
    @State private var isCannabisFlexible = false
    @State private var isKidsFlexible = false

    var body: some View {
        editNav(title: "Lifestyle", onSave: save) {
            sectionLabel("Habits")
            pickerRow("Drinks", selection: $drinks, options: ["Never", "Sometimes", "Often"])
            toggleRow("Flexible on drinking", isOn: $isDrinksFlexible)
            pickerRow("Smoking", selection: $smoking, options: ["Never", "Sometimes", "Often"])
            toggleRow("Flexible on smoking", isOn: $isSmokingFlexible)
            pickerRow("Workout", selection: $workout, options: ["Never", "Sometimes", "Often"])
            toggleRow("Flexible on workout", isOn: $isWorkoutFlexible)
            pickerRow("Sleep Schedule", selection: $sleepSchedule, options: ["Night Owl", "Early Bird", "Flexible"])
            toggleRow("Flexible on sleep schedule", isOn: $isSleepFlexible)
            pickerRow("Pets", selection: $pets, options: ["Don't want", "Unsure", "Want", "Have"])

            sectionLabel("More about pets")
            editField("What type of pets?", "e.g. Dog, Cat, Fish", text: $petTypes)
            editField("Pet's name", "e.g. Max, Luna", text: $petsName)

            sectionLabel("Cannabis")
            pickerRow("", selection: $cannabis, options: UserProfileStore.cannabisOptions)
            toggleRow("Flexible on cannabis", isOn: $isCannabisFlexible)

            sectionLabel("Kids")
            pickerRow("Children", selection: $children, options: UserProfileStore.childrenOptions)
            toggleRow("Flexible on kids", isOn: $isKidsFlexible)
        }
        .onAppear {
            drinks = store.drinks; smoking = store.smoking
            workout = store.workout; sleepSchedule = store.sleepSchedule
            pets = store.pets; cannabis = store.cannabis
            children = store.children
            petTypes = store.petTypes; petsName = store.petsName
            isDrinksFlexible = store.isDrinksFlexible; isSmokingFlexible = store.isSmokingFlexible
            isWorkoutFlexible = store.isWorkoutFlexible; isSleepFlexible = store.isSleepFlexible
            isCannabisFlexible = store.isCannabisFlexible; isKidsFlexible = store.isKidsFlexible
        }
    }

    private func save() {
        store.drinks = drinks; store.smoking = smoking
        store.workout = workout; store.sleepSchedule = sleepSchedule; store.pets = pets
        store.cannabis = cannabis
        store.children = children
        store.petTypes = petTypes; store.petsName = petsName
        store.isDrinksFlexible = isDrinksFlexible; store.isSmokingFlexible = isSmokingFlexible
        store.isWorkoutFlexible = isWorkoutFlexible; store.isSleepFlexible = isSleepFlexible
        store.isCannabisFlexible = isCannabisFlexible; store.isKidsFlexible = isKidsFlexible
        Task { await store.patchProfile() }; dismiss()
    }
}

// MARK: - Background Edit Sheet

struct BackgroundEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var ethnicities: Set<String> = []
    @State private var languages: Set<String> = []
    @State private var birthCountry = ""

    private static let ethnicityOptions = [
        "White", "Asian", "Hispanic/Latino", "Black/African American",
        "Native Hawaiian", "Pacific Islander", "Other+"
    ]
    private static let languageOptions = [
        "English", "Spanish", "Mandarin/Chinese", "Hindi", "Arabic",
        "French", "Portuguese", "Russian", "Japanese", "Korean",
        "German", "Vietnamese", "Italian", "Other+"
    ]
    private static let countries = [
        "United States", "Canada", "United Kingdom", "Australia", "India",
        "Mexico", "Brazil", "Germany", "France", "Japan", "South Korea",
        "China", "Nigeria", "Philippines", "Vietnam", "Spain", "Italy",
        "Pakistan", "Bangladesh", "Ethiopia", "Egypt", "Other"
    ]

    var body: some View {
        editNav(title: "Background", onSave: save) {
            sectionLabel("Ethnicity")
            FlowLayout(spacing: 8) {
                ForEach(Self.ethnicityOptions, id: \.self) { item in
                    backgroundChip(item, isSelected: ethnicities.contains(item)) {
                        if ethnicities.contains(item) { ethnicities.remove(item) }
                        else { ethnicities.insert(item) }
                    }
                }
            }

            sectionLabel("Languages")
            FlowLayout(spacing: 8) {
                ForEach(Self.languageOptions, id: \.self) { item in
                    backgroundChip(item, isSelected: languages.contains(item)) {
                        if languages.contains(item) { languages.remove(item) }
                        else { languages.insert(item) }
                    }
                }
            }

            pickerRow("Where were you born?", selection: $birthCountry, options: Self.countries)
        }
        .onAppear {
            ethnicities = Set(store.ethnicities)
            languages = Set(store.languages)
            birthCountry = store.birthCountry
        }
    }

    @ViewBuilder private func backgroundChip(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? AppTheme.iconColor : .white.opacity(0.7))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? AppTheme.iconColor.opacity(0.15) : Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? AppTheme.iconColor.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1))
                .clipShape(Capsule())
        }
    }

    private func save() {
        store.ethnicities = ethnicities.sorted()
        store.languages = languages.sorted()
        store.birthCountry = birthCountry
        Task { await store.patchProfile() }; dismiss()
    }
}

// MARK: - Career Edit Sheet

struct CareerEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var career = ""
    @State private var education = ""
    @State private var heightFt = ""
    @State private var heightIn = ""
    @State private var heightCm = ""
    @State private var heightUnit = "FT"
    @State private var jobTitle = ""
    @State private var school = ""

    @State private var showValidation = false

    private static let educationOptions = [
        "High School", "In College", "Bachelor's Degree",
        "Master's Degree", "PhD / Doctorate", "Other"
    ]
    private static let careerOptions = [
        "Technology", "Healthcare", "Education", "Finance", "Arts", "Other"
    ]

    private var isMandatoryFilled: Bool { !career.isEmpty && !education.isEmpty }

    var body: some View {
        editNav(title: "Career & Education", onSave: save) {
            requiredPicker("Career field", selection: $career, options: Self.careerOptions)
            requiredPicker("Education level", selection: $education, options: Self.educationOptions)
            editField("Job Title", "e.g. Software Engineer, Designer", text: $jobTitle)
            editField("School / University", "e.g. Harvard University", text: $school)
            sectionLabel("Height")
            heightPicker
        }
        .onAppear {
            career = store.career; education = store.education
            heightFt = store.heightFt; heightIn = store.heightIn
            heightCm = store.heightCm; heightUnit = store.heightUnit
            jobTitle = store.jobTitle; school = store.school
        }
    }

    @ViewBuilder private func requiredPicker(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                Text("*").foregroundStyle(.red).font(.system(size: 13, weight: .semibold))
            }
            Menu {
                Button("(none)") { selection.wrappedValue = "" }
                ForEach(options, id: \.self) { opt in Button(opt) { selection.wrappedValue = opt } }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "Select..." : selection.wrappedValue)
                        .font(.system(size: 15))
                        .foregroundStyle(selection.wrappedValue.isEmpty ? .white.opacity(0.3) : .white)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                }
                .padding(14).background(Color.white.opacity(0.07)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(showValidation && selection.wrappedValue.isEmpty ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1))
            }
            if showValidation && selection.wrappedValue.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11))
                    Text("Required").font(.system(size: 11))
                }.foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder private var heightPicker: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(["FT", "CM"], id: \.self) { unit in
                    Button { heightUnit = unit } label: {
                        Text(unit)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(heightUnit == unit ? .black : .white)
                            .frame(width: 44, height: 40)
                            .background(heightUnit == unit ? Color.white : Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            if heightUnit == "FT" {
                heightMenu(placeholder: "ft", selection: $heightFt, options: (3...8).map { String($0) }, width: 70)
                Text("ft").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                heightMenu(placeholder: "in", selection: $heightIn, options: (0...11).map { String($0) }, width: 70)
                Text("in").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
            } else {
                heightMenu(placeholder: "cm", selection: $heightCm, options: (91...272).map { String($0) }, width: 85)
                Text("cm").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder private func heightMenu(placeholder: String, selection: Binding<String>, options: [String], width: CGFloat) -> some View {
        Menu {
            ForEach(options, id: \.self) { opt in Button(opt) { selection.wrappedValue = opt } }
        } label: {
            HStack {
                Text(selection.wrappedValue.isEmpty ? placeholder : selection.wrappedValue)
                    .foregroundStyle(selection.wrappedValue.isEmpty ? .white.opacity(0.5) : .white)
                    .font(.system(size: 15))
                Spacer()
                Image(systemName: "chevron.up.chevron.down").foregroundStyle(.white.opacity(0.4)).font(.system(size: 11))
            }
            .padding(.horizontal, 12)
            .frame(width: width, height: 44)
            .background(.white.opacity(0.1))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }

    private func save() {
        showValidation = true
        guard isMandatoryFilled else { return }
        store.career = career; store.education = education
        store.heightFt = heightFt; store.heightIn = heightIn
        store.heightCm = heightCm; store.heightUnit = heightUnit
        store.jobTitle = jobTitle; store.school = school
        Task { await store.patchProfile() }; dismiss()
    }
}

// MARK: - Prompts Edit Sheet

struct PromptsEditSheet: View {
    @Environment(OnboardingData.self) private var onboarding
    @Environment(\.dismiss) private var dismiss

    @State private var q1 = ""; @State private var a1 = ""
    @State private var q2 = ""; @State private var a2 = ""
    @State private var q3 = ""; @State private var a3 = ""
    @State private var customQ = ""; @State private var customA = ""

    private static let promptOptions = [
        "A perfect day for me looks like...",
        "The most spontaneous thing I've done is...",
        "My love language in action looks like...",
        "I'm looking for someone who...",
        "A non-negotiable for me is...",
        "We'll get along if...",
        "My biggest green flag is...",
        "The way to my heart is...",
        "I geek out about...",
        "Two truths and a lie...",
        "I'm weirdly passionate about...",
        "I guarantee you'll laugh when...",
    ]

    var body: some View {
        editNav(title: "Prompts", onSave: save) {
            promptField("Prompt 1", question: $q1, answer: $a1, usedBy: [q2, q3])
            promptField("Prompt 2", question: $q2, answer: $a2, usedBy: [q1, q3])
            promptField("Prompt 3", question: $q3, answer: $a3, usedBy: [q1, q2])
            sectionLabel("Your own prompt")
            editField("Write your own question...", "", text: $customQ)
            if !customQ.isEmpty {
                editField("Your answer", "Write your answer...", text: $customA, multiline: true)
            }
        }
        .onAppear {
            q1 = onboarding.prompt1Question; a1 = onboarding.prompt1Answer
            q2 = onboarding.prompt2Question; a2 = onboarding.prompt2Answer
            q3 = onboarding.prompt3Question; a3 = onboarding.prompt3Answer
            customQ = onboarding.ownPrompt; customA = onboarding.ownPromptAnswer
        }
    }

    @ViewBuilder private func promptField(
        _ label: String, question: Binding<String>, answer: Binding<String>, usedBy: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Menu {
                Button("(none)") { question.wrappedValue = "" }
                ForEach(Self.promptOptions, id: \.self) { opt in
                    Button(opt) { question.wrappedValue = opt }
                        .disabled(usedBy.contains(opt))
                }
            } label: {
                HStack {
                    Text(question.wrappedValue.isEmpty ? "Choose a prompt..." : question.wrappedValue)
                        .font(.system(size: 14))
                        .foregroundStyle(question.wrappedValue.isEmpty ? .white.opacity(0.4) : .white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(14).background(Color.white.opacity(0.07)).cornerRadius(12)
            }
            if !question.wrappedValue.isEmpty {
                editField("Your answer", "Write your answer...", text: answer, multiline: true)
            }
        }
    }

    private func save() {
        onboarding.prompt1Question = q1; onboarding.prompt1Answer = a1
        onboarding.prompt2Question = q2; onboarding.prompt2Answer = a2
        onboarding.prompt3Question = q3; onboarding.prompt3Answer = a3
        onboarding.ownPrompt = customQ; onboarding.ownPromptAnswer = customA
        onboarding.save(); dismiss()
    }
}

// MARK: - Preferences Edit Sheet (Looking For + Discovery Settings combined)

struct PreferencesEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var goals: Set<String> = []
    @State private var meetPref  = ""
    @State private var minAge: Double = 18
    @State private var maxAge: Double = 50
    @State private var distance: Double = 25
    @State private var showValidation = false

    var body: some View {
        editNav(title: "Preferences", onSave: save) {
            // I'm looking for
            requiredLabel("I'm looking for")
            FlowLayout(spacing: 8) {
                ForEach(UserProfileStore.relationshipGoalOptions, id: \.self) { opt in
                    let on = goals.contains(opt)
                    let atMax = goals.count >= 2 && !on
                    Button {
                        if on { goals.remove(opt) } else if !atMax { goals.insert(opt) }
                    } label: {
                        Text(opt)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(on ? AppTheme.iconColor : atMax ? .white.opacity(0.2) : .white.opacity(0.7))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(on ? AppTheme.iconColor.opacity(0.15) : Color.white.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 20)
                                .stroke(on ? AppTheme.iconColor.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .disabled(atMax)
                }
            }
            if showValidation && goals.isEmpty {
                validationError("Please select at least one")
            }

            // Open to meeting
            requiredLabel("Open to meeting")
            pickerRow("", selection: $meetPref, options: UserProfileStore.meetPreferenceOptions)
            if showValidation && meetPref.isEmpty {
                validationError("Please select who you'd like to meet")
            }

            // Age Range
            requiredLabel("Age Preference", required: true)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text("\(Int(minAge)) – \(Int(maxAge))")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                }
                DualSlider(minValue: $minAge, maxValue: $maxAge, bounds: 18...80)
            }
            .padding(14).background(Color.white.opacity(0.07)).cornerRadius(12)

            // Distance
            requiredLabel("Distance Preference", required: true)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text("Within \(Int(distance)) mi")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                }
                Slider(value: $distance, in: 1...100, step: 1).tint(AppTheme.primaryButton)
            }
            .padding(14).background(Color.white.opacity(0.07)).cornerRadius(12)
        }
        .onAppear {
            goals    = Set(store.relationshipGoals)
            meetPref = store.meetPreference
            minAge   = store.minAge
            maxAge   = store.maxAge
            distance = store.distance
        }
    }

    private func save() {
        guard !goals.isEmpty && !meetPref.isEmpty else { showValidation = true; return }
        store.relationshipGoals = goals.sorted()
        store.meetPreference    = meetPref
        store.minAge            = minAge
        store.maxAge            = maxAge
        store.distance          = distance
        Task { await store.patchProfile() }; dismiss()
    }
}
