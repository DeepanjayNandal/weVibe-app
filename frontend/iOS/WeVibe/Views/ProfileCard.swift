import SwiftUI

// MARK: - ProfileCardView
// Renders a profile (own or match) from ProfileDisplayData.
// Data models:   Services/ProfileDisplayData.swift
// Sub-components: Components/ProfileComponents.swift

// MARK: - Theme palette
private struct CardTheme {
    let bg:         Color   // page background
    let sectionBg:  Color   // card background
    let separator:  Color   // dividers / card borders
    let primary:    Color   // main text
    let secondary:  Color   // label / muted text
    let tertiary:   Color   // placeholder / empty hint
    let iconBg:     Color   // circle behind gear/X buttons
    let accent:     Color   // badges, "flexible" tag, activity chips, pronouns — must contrast on bg
    let isLight:    Bool

    static let dark = CardTheme(
        bg:        Color(hex: "#0D2329"),
        sectionBg: Color.white.opacity(0.05),
        separator: Color.white.opacity(0.08),
        primary:   Color.white,
        secondary: Color.white.opacity(0.8),
        tertiary:  Color.white.opacity(0.4),
        iconBg:    Color.white.opacity(0.1),
        accent:    AppTheme.iconColor,          // lime #D1FF5D — readable on dark
        isLight:   false
    )

    static let light = CardTheme(
        bg:        Color(hex: "#F2F2F7"),        // light gray page — makes white cards pop
        sectionBg: Color(hex: "#FFFFFF"),        // white cards
        separator: Color(hex: "#D1D1D6"),        // visible dividers
        primary:   Color(hex: "#1C1C1E"),
        secondary: Color(hex: "#6C6C70"),
        tertiary:  Color(hex: "#AEAEB2"),
        iconBg:    Color(hex: "#E5E5EA"),
        accent:    AppTheme.primaryButton,      // dark green #05664F — readable on white
        isLight:   true
    )
}

struct ProfileCardView: View {
    let data: ProfileDisplayData
    let mode: ProfileCardMode

    @AppStorage("profileCardLightTheme") private var isLightTheme: Bool = false

    @State private var showRemoveAlert = false
    @State private var showLightbox    = false
    @State private var lightboxStart   = 0

    private var t: CardTheme { isLightTheme ? .light : .dark }

    private var isOwnProfile: Bool {
        if case .ownProfile = mode { return true }
        return false
    }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    photoCarousel
                    nameHeader
                    sectionsBody
                }
                .padding(.bottom, isOwnProfile ? 110 : 40)
            }
        }
        .fullScreenCover(isPresented: $showLightbox) {
            PhotoLightboxView(urls: data.photoURLs, startIndex: lightboxStart)
        }
        .alert("Remove from Matches?", isPresented: $showRemoveAlert) {
            if case .matchProfile(_, let onRemove) = mode {
                Button("Yes", role: .destructive) { onRemove() }
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Do you want to remove this user from your matches?")
        }
    }

    // MARK: - Header button

    private var headerButton: some View {
        Group {
            switch mode {
            case .ownProfile(_, let onSettings):
                Button { onSettings() } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(t.secondary)
                        .padding(10)
                        .background(t.iconBg, in: Circle())
                }
            case .matchProfile(let onDismiss, _):
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(t.secondary)
                        .padding(10)
                        .background(t.iconBg, in: Circle())
                }
            }
        }
    }

    // MARK: - Photo Area

    private var photoCarousel: some View {
        Group {
            if data.photoURLs.isEmpty {
                t.sectionBg
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .overlay {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(t.separator)
                                    .frame(width: 100, height: 100)
                                Text(String(data.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(t.tertiary)
                            }
                            if isOwnProfile, case .ownProfile(let onEdit, _) = mode {
                                Button { onEdit(.photos) } label: {
                                    Label("Add Photos", systemImage: "camera.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(t.accent)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(t.accent.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
            } else {
                Button {
                    lightboxStart = 0
                    showLightbox = true
                } label: {
                    AsyncImage(url: URL(string: data.photoURLs[0])) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { t.sectionBg }
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .clipped()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, t.bg],
                        startPoint: .init(x: 0.5, y: t.isLight ? 0.6 : 0.5), endPoint: .bottom
                    )
                    .frame(height: 140)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    HStack {
                        if data.photoURLs.count > 1 {
                            Label("1 / \(data.photoURLs.count)", systemImage: "photo.on.rectangle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.black.opacity(0.45), in: Capsule())
                        }
                        Spacer()
                        if isOwnProfile, case .ownProfile(let onEdit, _) = mode {
                            Button { onEdit(.photos) } label: {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.black.opacity(0.45), in: Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Name Header

    private var nameHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(data.age > 0 ? "\(data.displayName), \(data.age)" : data.displayName)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(t.primary)
                Spacer()
                headerButton
            }
            if !data.jobTitle.isEmpty {
                Text(data.jobTitle)
                    .font(.system(size: 16))
                    .foregroundStyle(t.secondary)
            }
            if !data.pronouns.isEmpty {
                Text(data.pronouns)
                    .font(.system(size: 14))
                    .foregroundStyle(t.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(t.accent.opacity(0.12))
                    .clipShape(Capsule())
            }
            let hasSocial = !data.instagramHandle.isEmpty || !data.tiktokHandle.isEmpty || !data.spotifyURL.isEmpty
            if hasSocial {
                FlowLayout(spacing: 8) {
                    if !data.instagramHandle.isEmpty {
                        SocialBadge(platform: .instagram(data.instagramHandle))
                    }
                    if !data.tiktokHandle.isEmpty {
                        SocialBadge(platform: .tiktok(data.tiktokHandle))
                    }
                    if !data.spotifyURL.isEmpty {
                        SocialBadge(platform: .spotify(data.spotifyURL))
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
    }

    // MARK: - All Sections

    private var sectionsBody: some View {
        VStack(spacing: 12) {
            let aboutHasContent = (data.showSex && !data.sex.isEmpty)
                || (data.showLocation && !data.locationDisplay.isEmpty)
                || !data.bio.isEmpty
            section(id: .about, title: "About Me", isVisible: true, hasContent: aboutHasContent) {
                VStack(alignment: .leading, spacing: 12) {
                    let hasGender = data.showSex && !data.sex.isEmpty
                    let hasLocation = data.showLocation && !data.locationDisplay.isEmpty
                    if hasGender || hasLocation {
                        rowGrid {
                            if hasGender {
                                infoRow("person.fill", "Gender", data.sex)
                            }
                            if hasLocation {
                                infoRow("location.fill", "Location", data.locationDisplay)
                            }
                        }
                        if !data.bio.isEmpty { Divider().overlay(t.separator) }
                    }
                    if data.bio.isEmpty && isOwnProfile {
                        emptyHint("Add a bio to tell people about yourself")
                    } else if !data.bio.isEmpty {
                        Text(data.bio)
                            .font(.system(size: 15))
                            .foregroundStyle(t.primary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            let identityHasContent = (!data.orientation.isEmpty && data.showOrientation) || !data.identity.isEmpty
            section(id: .identity, title: "Identity", isVisible: data.showOrientation, hasContent: identityHasContent) {
                if data.orientation.isEmpty && data.identity.isEmpty && isOwnProfile {
                    emptyHint("Add your orientation and identity")
                } else {
                    rowGrid {
                        if !data.orientation.isEmpty && data.showOrientation {
                            infoRow("person.fill", "Orientation", data.orientation)
                        }
                        if !data.identity.isEmpty {
                            infoRow("sparkles", "Identity", data.identity)
                        }
                    }
                }
            }

            let personalityHasContent = !data.personalityType.isEmpty || !data.loveLanguage.isEmpty
                || !data.zodiacSign.isEmpty || !data.communicationStyle.isEmpty || !data.conflictStyle.isEmpty
            section(id: .personality, title: "Personality", isVisible: data.showPersonalityTrait, hasContent: personalityHasContent) {
                if data.personalityType.isEmpty && data.loveLanguage.isEmpty && data.zodiacSign.isEmpty
                    && data.communicationStyle.isEmpty && data.conflictStyle.isEmpty && isOwnProfile {
                    emptyHint("Add your personality details")
                } else {
                    rowGrid {
                        if !data.personalityType.isEmpty { infoRow("brain.head.profile", "Type", data.personalityType) }
                        if !data.loveLanguage.isEmpty    { infoRow("heart.fill", "Love Language", data.loveLanguage) }
                        if !data.zodiacSign.isEmpty      { infoRow("moon.stars.fill", "Zodiac", data.zodiacSign) }
                        if !data.communicationStyle.isEmpty {
                            infoRow("bubble.left.fill", "Communication", data.communicationStyle)
                        }
                        if !data.conflictStyle.isEmpty {
                            infoRow("bolt.fill", "Conflict Style", data.conflictStyle)
                        }
                    }
                }
            }

            section(id: .interests, title: "Interests & Hobbies", isVisible: data.showInterests, hasContent: !data.interests.isEmpty) {
                if data.interests.isEmpty && isOwnProfile {
                    emptyHint("Add your interests and hobbies")
                } else if !data.interests.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(data.interests.enumerated()), id: \.element) { idx, interest in
                            InterestChipView(text: interest, colorIndex: idx)
                        }
                    }
                }
            }

            let dateHasContent = !data.preferredDateActivities.isEmpty || !data.wouldNotDoActivities.isEmpty
            section(id: .dateActivities, title: "Date Activities", isVisible: true, hasContent: dateHasContent) {
                VStack(alignment: .leading, spacing: 10) {
                    if !data.preferredDateActivities.isEmpty {
                        activityGroup(title: "Would love to:", items: data.preferredDateActivities,
                                      color: t.accent)
                    }
                    if !data.wouldNotDoActivities.isEmpty {
                        activityGroup(title: "Not really into:", items: data.wouldNotDoActivities,
                                      color: Color(hex: "#C0392B"))
                    }
                    if data.preferredDateActivities.isEmpty && data.wouldNotDoActivities.isEmpty && isOwnProfile {
                        emptyHint("Add your date activity preferences")
                    }
                }
            }

            let lifestyleHasContent = !data.drinks.isEmpty || !data.smoking.isEmpty || !data.cannabis.isEmpty
                || !data.workout.isEmpty || !data.sleepSchedule.isEmpty || !data.pets.isEmpty || !data.children.isEmpty
            section(id: .lifestyle, title: "Lifestyle", isVisible: data.showLifestyle, hasContent: lifestyleHasContent) {
                let anyFilled = lifestyleHasContent
                if !anyFilled && isOwnProfile {
                    emptyHint("Add your lifestyle details")
                } else {
                    rowGrid {
                        if !data.drinks.isEmpty      { lifestyleRow("wineglass.fill", "Drinks",   data.drinks,        data.isDrinksFlexible) }
                        if !data.smoking.isEmpty     { lifestyleRow("flame.fill",     "Smoking",  data.smoking,       data.isSmokingFlexible) }
                        if !data.cannabis.isEmpty    { lifestyleRow("leaf.fill",      "Cannabis", data.cannabis,      data.isCannabisFlexible) }
                        if !data.workout.isEmpty     { lifestyleRow("figure.run",     "Workout",  data.workout,       data.isWorkoutFlexible) }
                        if !data.sleepSchedule.isEmpty { lifestyleRow("moon.fill",    "Sleep",    data.sleepSchedule, data.isSleepFlexible) }
                        if !data.pets.isEmpty        { infoRow("pawprint.fill",  "Pets",     data.pets) }
                        if !data.petTypes.isEmpty    { infoRow("pawprint",       "Pet type", data.petTypes) }
                        if !data.petsName.isEmpty    { infoRow("heart.fill",     "Pet name", data.petsName) }
                        if !data.children.isEmpty    { infoRow("person.2.fill",  "Kids",     data.children) }
                    }
                }
            }

            let bgHasContent = !data.ethnicities.isEmpty || !data.birthCountry.isEmpty || !data.languages.isEmpty
            section(id: .background, title: "Background", isVisible: true, hasContent: bgHasContent) {
                if data.ethnicities.isEmpty && data.birthCountry.isEmpty && data.languages.isEmpty && isOwnProfile {
                    emptyHint("Add your background details")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if !data.ethnicities.isEmpty { tagGroup(title: "Ethnicity", items: data.ethnicities) }
                        if !data.birthCountry.isEmpty {
                            rowGrid { infoRow("globe", "Born in", data.birthCountry) }
                        }
                        if !data.languages.isEmpty { tagGroup(title: "Languages", items: data.languages) }
                    }
                }
            }

            let careerRows: [(String, String, String)] = [
                ("briefcase.fill",        "Career",    data.career),
                ("tag.fill",              "Job title", data.jobTitle),
                ("building.columns.fill", "School",    data.school),
                ("graduationcap.fill",    "Education", data.education),
                ("ruler.fill",            "Height",    data.heightDisplay),
            ].filter { !$2.isEmpty }
            section(id: .career, title: "Career & Education", isVisible: data.showCareer, hasContent: !careerRows.isEmpty) {
                if careerRows.isEmpty && isOwnProfile {
                    emptyHint("Add your career and education")
                } else {
                    rowGrid {
                        ForEach(careerRows, id: \.1) { icon, label, value in infoRow(icon, label, value) }
                    }
                }
            }

            section(id: .prompts, title: "Prompts", isVisible: true, hasContent: !data.prompts.isEmpty) {
                if data.prompts.isEmpty && isOwnProfile {
                    emptyHint("Add prompts to show your personality")
                } else if !data.prompts.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(data.prompts.enumerated()), id: \.offset) { idx, pair in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pair.question)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryButton)
                                Text(pair.answer.isEmpty ? "No answer yet" : pair.answer)
                                    .font(.system(size: 15))
                                    .foregroundStyle(pair.answer.isEmpty ? t.tertiary : t.primary)
                                    .lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if idx < data.prompts.count - 1 {
                                Divider().overlay(t.separator)
                            }
                        }
                    }
                }
            }

            if isOwnProfile { section(id: .preferences, title: "Preferences", isVisible: true) {
                let hasContent = !data.relationshipGoals.isEmpty || !data.meetPreference.isEmpty || data.minAge > 0
                if hasContent {
                    VStack(alignment: .leading, spacing: 10) {
                        if !data.relationshipGoals.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(data.relationshipGoals, id: \.self) { goal in
                                    Text(goal)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(t.accent)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(t.accent.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        rowGrid {
                            if !data.meetPreference.isEmpty {
                                infoRow("figure.2.arms.open", "Open to", data.meetPreference)
                            }
                            if data.minAge > 0 {
                                infoRow("calendar", "Age", "\(data.minAge) – \(data.maxAge)")
                            }
                            if data.distance > 0 && isOwnProfile {
                                infoRow("location.circle", "Distance", "Within \(Int(data.distance)) mi")
                            }
                        }
                    }
                } else if isOwnProfile {
                    emptyHint("Add your preferences")
                }
            } } // end if isOwnProfile + section

            footerActions
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerActions: some View {
        switch mode {
        case .ownProfile:
            EmptyView()
        case .matchProfile:
            Button { showRemoveAlert = true } label: {
                Text("Remove from Matches")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#C0392B"))
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Section Card Builder

    @ViewBuilder
    private func section<Content: View>(
        id: ProfileCardSection?,
        title: String,
        isVisible: Bool,
        hasContent: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // In matchProfile mode, skip rendering the card entirely if there's nothing to show
        if isOwnProfile || hasContent {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(t.secondary.opacity(0.7))
                    .tracking(0.8)
                Spacer()
                switch mode {
                case .ownProfile(let onEdit, _):
                    if let sectionId = id {
                        Button { onEdit(sectionId) } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(t.isLight ? AppTheme.primaryButton : .white.opacity(0.4))
                        }
                    }
                case .matchProfile:
                    Image(systemName: isVisible ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(isVisible ? Color(hex: "#34C759") : Color(hex: "#FF3B30"))
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            content()
                .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.sectionBg)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.separator, lineWidth: 1))
        } // end if isOwnProfile || hasContent
    }

    // MARK: - Row grid wrapper

    private func rowGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Display helpers (used inside rowGrid)

    @ViewBuilder
    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        GridRow {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.primaryButton)
                .gridColumnAlignment(.center)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(t.secondary)
                .gridColumnAlignment(.leading)
                .fixedSize(horizontal: true, vertical: false)
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(t.primary)
                .gridColumnAlignment(.leading)
        }
    }

    @ViewBuilder
    private func lifestyleRow(_ icon: String, _ label: String, _ value: String, _ flexible: Bool) -> some View {
        GridRow {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.primaryButton)
                .gridColumnAlignment(.center)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(t.secondary)
                .gridColumnAlignment(.leading)
                .fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(t.primary)
                if flexible {
                    Text("flexible")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(t.accent)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(t.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .gridColumnAlignment(.leading)
        }
    }

    @ViewBuilder
    private func tagGroup(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13)).foregroundStyle(t.secondary)
            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(t.primary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(t.isLight ? Color(hex: "#E5E5EA") : Color.white.opacity(0.1))
                        .cornerRadius(20)
                }
            }
        }
    }

    @ViewBuilder
    private func activityGroup(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13)).foregroundStyle(t.secondary)
            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(t.isLight ? color : .white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(color.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.4), lineWidth: 1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func emptyHint(_ text: String) -> some View {
        Text(text).font(.system(size: 15)).foregroundStyle(t.tertiary).italic()
    }
}

// MARK: - Photo Lightbox

struct PhotoLightboxView: View {
    let urls: [String]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(urls: [String], startIndex: Int) {
        self.urls = urls
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(urls.indices, id: \.self) { i in
                    AsyncImage(url: URL(string: urls[i])) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                    .tag(i)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            HStack {
                Text("\(currentIndex + 1) / \(urls.count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.15), in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)

            VStack {
                Spacer()
                HStack(spacing: 5) {
                    ForEach(urls.indices, id: \.self) { i in
                        Circle()
                            .fill(i == currentIndex ? Color.white : Color.white.opacity(0.35))
                            .frame(width: i == currentIndex ? 8 : 5, height: i == currentIndex ? 8 : 5)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}
