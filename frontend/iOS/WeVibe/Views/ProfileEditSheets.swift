import SwiftUI
import PhotosUI
import FirebaseAuth

// MARK: - PhotoItem

/// Unified model for both already-uploaded and newly picked photos.
/// Lets the single grid reorder all items together before saving.
private enum PhotoItem: Identifiable {
    case existing(UserPhoto)
    case new(id: String, image: UIImage)

    var id: String {
        switch self {
        case .existing(let p):    return p.id
        case .new(let id, _):     return id
        }
    }
}

// MARK: - Photos Edit Sheet

struct PhotosEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var photoItems: [PhotoItem] = []
    @State private var removedPhotoIds: Set<String> = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isSaving: Bool = false
    @State private var uploadProgress: String = ""
    @State private var saveError: String? = nil
    @State private var draggingItemId: String? = nil
    @State private var cropQueue: [UIImage] = []

    private static let maxPhotos = 6
    private var totalCount: Int { photoItems.count }
    private var remaining: Int { Swift.max(0, Self.maxPhotos - totalCount) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        infoNote("Up to \(Self.maxPhotos) photos. Photos are stored in the cloud.")

                        if let err = saveError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }

                        if isSaving && !uploadProgress.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView().tint(AppTheme.iconColor)
                                Text(uploadProgress)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !photoItems.isEmpty {
                            Text("Hold & drag to reorder")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                        let columns = [GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(photoItems) { item in
                                photoCell {
                                    switch item {
                                    case .existing(let photo):
                                        AsyncImage(url: URL(string: photo.url)) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: {
                                            AppTheme.secondaryBackground
                                        }
                                    case .new(_, let image):
                                        Image(uiImage: image).resizable().scaledToFill()
                                    }
                                } onRemove: {
                                    if case .existing(let photo) = item {
                                        removedPhotoIds.insert(photo.id)
                                    }
                                    photoItems.removeAll { $0.id == item.id }
                                }
                                .opacity(draggingItemId == item.id ? 0.4 : 1.0)
                                .draggable(item.id) {
                                    Group {
                                        switch item {
                                        case .existing(let photo):
                                            AsyncImage(url: URL(string: photo.url)) { img in
                                                img.resizable().scaledToFill()
                                            } placeholder: {
                                                AppTheme.secondaryBackground
                                            }
                                        case .new(_, let image):
                                            Image(uiImage: image).resizable().scaledToFill()
                                        }
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onAppear { draggingItemId = item.id }
                                }
                                .dropDestination(for: String.self) { droppedIds, _ in
                                    draggingItemId = nil
                                    guard let droppedId = droppedIds.first,
                                          droppedId != item.id,
                                          let from = photoItems.firstIndex(where: { $0.id == droppedId }),
                                          let to = photoItems.firstIndex(where: { $0.id == item.id })
                                    else { return false }
                                    withAnimation { photoItems.move(fromOffsets: IndexSet(integer: from),
                                                                    toOffset: to > from ? to + 1 : to) }
                                    return true
                                }
                            }
                            if totalCount < Self.maxPhotos {
                                PhotosPicker(
                                    selection: $pickerItems,
                                    maxSelectionCount: remaining,
                                    matching: .images
                                ) {
                                    addSlotLabel
                                }
                                .disabled(isSaving)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Photos (\(totalCount)/\(Self.maxPhotos))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.secondaryBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(isSaving ? 0.3 : 0.6))
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(AppTheme.iconColor)
                    } else {
                        Button("Save") { Task { await save() } }
                            .foregroundStyle(AppTheme.iconColor).fontWeight(.semibold)
                    }
                }
            }
            .onChange(of: pickerItems) { loadNewImages() }
            .fullScreenCover(
                isPresented: Binding(
                    get: { !cropQueue.isEmpty },
                    set: { if !$0 { cropQueue.removeAll() } }
                )
            ) {
                if let img = cropQueue.first {
                    ImageCropView(image: img) { cropped in
                        cropQueue.removeFirst()
                        photoItems.append(.new(id: UUID().uuidString, image: cropped))
                    } onCancel: {
                        cropQueue.removeFirst()
                    }
                    .id(cropQueue.count)
                }
            }
        }
        .onAppear { photoItems = store.photos.map { .existing($0) } }
    }

    @ViewBuilder
    private var addSlotLabel: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(AppTheme.iconColor)
            Text("\(remaining) left")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
            .foregroundStyle(AppTheme.iconColor.opacity(0.4)))
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func photoCell<Content: View>(
        @ViewBuilder image: () -> Content,
        onRemove: @escaping () -> Void
    ) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                image()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
                .padding(6)
                .disabled(isSaving)
            }
    }

    private func loadNewImages() {
        // Snapshot and reset so the picker opens fresh on the next tap.
        let itemsToLoad = pickerItems
        pickerItems = []
        for item in itemsToLoad {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data, let img = UIImage(data: data) {
                    // Normalize EXIF orientation — UIImage(data:) preserves the rotation
                    // flag but SwiftUI can render it incorrectly, making thumbnails look
                    // stretched or rotated. Drawing into a new context produces a clean .up image.
                    let normalized = img.normalizedForDisplay()
                    DispatchQueue.main.async {
                        cropQueue.append(normalized)
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false; uploadProgress = "" }

        guard let user = Auth.auth().currentUser else {
            saveError = "Session expired. Please sign in again."
            return
        }
        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            saveError = "Session expired. Please sign in again."
            return
        }

        let client = APIClient()

        // 1. Delete removed photos sequentially — backend does read-modify-write on
        //    the photos JSON column with no locking, so parallel deletes race and
        //    the last write wins, leaving orphaned DB records pointing to deleted GCS files.
        if !removedPhotoIds.isEmpty {
            uploadProgress = "Removing photos…"
            for photoId in removedPhotoIds {
                try? await client.deletePhoto(token: token, photoId: photoId)
            }
        }

        // 2. Upload new images in their current grid order
        let newImages = photoItems.compactMap { item -> UIImage? in
            if case .new(_, let img) = item { return img }
            return nil
        }
        var uploadedPhotos: [UserPhoto] = []
        for (i, image) in newImages.enumerated() {
            uploadProgress = "Uploading photo \(i + 1) of \(newImages.count)…"
            guard let jpegData = compress(image) else { continue }
            do {
                let urlResult = try await client.requestPhotoUploadURL(
                    token: token, mimeType: "image/jpeg", sizeBytes: jpegData.count
                )
                try await client.uploadPhotoData(jpegData, to: urlResult.uploadURL)

                // Finalize with retry: the GCS bytes are already uploaded at this point.
                // If finalize fails transiently, retrying avoids leaving an orphaned GCS file.
                // Note: a server-side cleanup job should also sweep unfinalized photoIds older
                // than ~1 hour to handle cases where all client retries are exhausted.
                var photo: UserPhoto?
                var finalizeError: Error?
                for attempt in 1...3 {
                    do {
                        photo = try await client.finalizePhotoUpload(
                            token: token, photoId: urlResult.photoId, order: i
                        )
                        finalizeError = nil
                        break
                    } catch {
                        finalizeError = error
                        if attempt < 3 {
                            try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                        }
                    }
                }
                if let err = finalizeError { throw err }
                uploadedPhotos.append(photo!)
            } catch {
                saveError = "Failed to upload photo \(i + 1). Please try again."
                return
            }
        }

        // 3. Reorder using the unified grid order: walk photoItems, replacing .new slots
        //    with their uploaded UserPhoto in sequence.
        var uploadIterator = uploadedPhotos.makeIterator()
        let finalPhotos = photoItems.compactMap { item -> UserPhoto? in
            switch item {
            case .existing(let photo): return removedPhotoIds.contains(photo.id) ? nil : photo
            case .new:                 return uploadIterator.next()
            }
        }
        if finalPhotos.count > 1 {
            uploadProgress = "Saving order…"
            let orders = finalPhotos.enumerated().map { (idx, photo) in (photoId: photo.id, order: idx) }
            try? await client.reorderPhotos(token: token, orders: orders)
        }

        // 4. Re-fetch and close
        uploadProgress = "Finishing…"
        await store.fetchProfile()
        dismiss()
    }

    private func compress(_ image: UIImage, maxDimension: CGFloat = 1200, quality: CGFloat = 0.8) -> Data? {
        let size = image.size
        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = min(maxDimension / size.width, maxDimension / size.height)
        } else {
            scale = 1.0
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        // scale=1 so pixel dimensions == newSize; without this the renderer inherits
        // the screen scale (3×) and the JPEG encodes at 9× the intended pixel count.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }
}

// MARK: - UIImage orientation normalization

private extension UIImage {
    /// Returns a copy of the image drawn in the `.up` orientation.
    /// Required because `UIImage(data:)` preserves the EXIF rotation flag, which
    /// SwiftUI's `Image(uiImage:)` can render incorrectly in grid cells.
    /// Normalizes EXIF orientation AND scales down to `maxDimension` in one pass.
    /// Keeping photos at full resolution (~48 MB uncompressed per 12 MP frame) causes
    /// OOM crashes when 3+ are loaded simultaneously. 1200 px is plenty for a
    /// 120 pt thumbnail at 3× and matches the upload compress() target.
    func normalizedForDisplay(maxDimension: CGFloat = 1200) -> UIImage {
        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = min(maxDimension / size.width, maxDimension / size.height)
        } else if imageOrientation == .up {
            return self
        } else {
            scale = 1.0
        }
        let newSize = CGSize(width: (size.width * scale).rounded(),
                             height: (size.height * scale).rounded())
        // Force scale=1 so image.size == pixel dimensions.
        // Without this, UIGraphicsImageRenderer inherits the screen scale (3×),
        // producing an image where size=(1200,899) pts but cgImage is 3600×2697 px —
        // which breaks any code that maps UIImage.size back to CGImage pixel coordinates.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
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
    @State private var isSaving = false
    @State private var isGeneratingBio = false
    @State private var bioGenerateError: String? = nil
    @State private var bioRemaining: Int? = nil

    var body: some View {
        editNav(title: "About Me", isSaving: isSaving, onCancel: { dismiss() }, onSave: save) {
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
            generateBioButton
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

    @ViewBuilder
    private var generateBioButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await generateBio() }
            } label: {
                HStack(spacing: 8) {
                    if isGeneratingBio {
                        ProgressView().tint(.black).scaleEffect(0.8)
                        Text("Generating…")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Generate Bio with AI")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isGeneratingBio ? AppTheme.iconColor.opacity(0.6) : AppTheme.iconColor)
                .cornerRadius(12)
            }
            .disabled(isGeneratingBio)

            if let remaining = bioRemaining {
                Text("\(remaining) generation\(remaining == 1 ? "" : "s") left today")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if let err = bioGenerateError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 12))
                    Text(err).font(.system(size: 12))
                }
                .foregroundStyle(Color(hex: "#E74C3C"))
            }
        }
    }

    private func generateBio() async {
        bioGenerateError = nil
        isGeneratingBio = true
        defer { isGeneratingBio = false }

        guard let user = Auth.auth().currentUser else {
            bioGenerateError = "Session expired. Please sign in again."
            return
        }
        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            bioGenerateError = "Session expired. Please sign in again."
            return
        }

        do {
            let result = try await APIClient().generateBio(token: token)
            bio = result.bio
            bioRemaining = result.remainingToday
        } catch APIError.rateLimited(let msg) {
            bioGenerateError = msg
        } catch APIError.unauthorized {
            bioGenerateError = "Session expired. Please sign in again."
        } catch {
            bioGenerateError = "Generation failed. Please try again."
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
        var p = ProfileUpdatePayload()
        p.firstName         = fn
        p.lastName          = ln
        p.bio               = bio.isEmpty          ? nil : bio
        p.instagramHandle   = instagram.isEmpty    ? nil : instagram
        p.tiktokHandle      = tiktok.isEmpty       ? nil : tiktok
        p.spotifyPlaylistUrl = spotify.isEmpty     ? nil : spotify
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
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
    @State private var isSaving = false

    var body: some View {
        editNav(title: "Identity", isSaving: isSaving, onCancel: { dismiss() }, onSave: save) {
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
        var p = ProfileUpdatePayload()
        p.pronouns      = pronouns.isEmpty    ? nil : pronouns
        p.orientation   = orientation.isEmpty ? nil : orientation
        p.showGender    = showSex
        p.showOrientation = showOrientation
        p.genderIdentity  = identity.isEmpty  ? nil : identity
        p.showIdentity    = showIdentity
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
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
    @State private var isSaving = false

    var body: some View {
        editNav(title: "Personality", isSaving: isSaving, onCancel: { dismiss() }, onSave: save) {
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
        var p = ProfileUpdatePayload()
        p.loveLanguage       = loveLanguage.isEmpty ? nil : loveLanguage
        p.zodiacSign         = zodiac.isEmpty       ? nil : zodiac
        p.communicationStyle = comm.isEmpty         ? nil : comm
        p.conflictStyle      = conflict.isEmpty     ? nil : conflict
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
    }
}

// MARK: - Interests Edit Sheet

struct InterestsEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var searchText = ""
    @State private var isSaving = false

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
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(isSaving ? 0.3 : 0.6))
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(AppTheme.iconColor)
                    } else {
                        Button("Save") { save() }.foregroundStyle(AppTheme.iconColor).fontWeight(.semibold)
                    }
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
        var p = ProfileUpdatePayload()
        p.interests = store.interests.isEmpty ? nil : store.interests
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
    }
}

// MARK: - Date Activities Edit Sheet

struct DateActivitiesEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var wouldDo: Set<String> = []
    @State private var wouldNot: Set<String> = []
    @State private var isSaving = false

    private static let maxActivities = 3

    var body: some View {
        editNav(title: "Date Activities", isSaving: isSaving, onCancel: { dismiss() }, onSave: save) {
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
        var p = ProfileUpdatePayload()
        p.preferredDateActivities = store.preferredDateActivities.isEmpty ? nil : store.preferredDateActivities
        p.wouldNotDoActivities    = store.wouldNotDoActivities.isEmpty    ? nil : store.wouldNotDoActivities
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
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
    @State private var isSaving = false

    var body: some View {
        editNav(title: "Lifestyle", isSaving: isSaving, onCancel: { dismiss() }, onSave: save) {
            sectionLabel("Habits")
            pickerRow("Drinks", selection: $drinks, options: FrequencyHabit.allCases.map(\.rawValue))
            toggleRow("Flexible on drinking", isOn: $isDrinksFlexible)
            pickerRow("Smoking", selection: $smoking, options: FrequencyHabit.allCases.map(\.rawValue))
            toggleRow("Flexible on smoking", isOn: $isSmokingFlexible)
            pickerRow("Workout", selection: $workout, options: FrequencyHabit.allCases.map(\.rawValue))
            toggleRow("Flexible on workout", isOn: $isWorkoutFlexible)
            pickerRow("Sleep Schedule", selection: $sleepSchedule, options: SleepSchedule.allCases.map(\.rawValue))
            toggleRow("Flexible on sleep schedule", isOn: $isSleepFlexible)
            pickerRow("Pets", selection: $pets, options: FamilyPreference.allCases.map(\.rawValue))

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
        var p = ProfileUpdatePayload()
        p.drinks       = drinks.isEmpty       ? nil : drinks
        p.smoking      = smoking.isEmpty      ? nil : smoking
        p.workout      = workout.isEmpty      ? nil : workout
        p.sleepSchedule = sleepSchedule.isEmpty ? nil : sleepSchedule
        p.pets         = pets.isEmpty         ? nil : pets
        p.cannabis     = cannabis.isEmpty     ? nil : cannabis
        p.petTypes     = petTypes.isEmpty     ? nil : petTypes
        p.petsName     = petsName.isEmpty     ? nil : petsName
        p.children     = children.isEmpty     ? nil : children
        p.isDrinksFlexible   = isDrinksFlexible
        p.isSmokingFlexible  = isSmokingFlexible
        p.isWorkoutFlexible  = isWorkoutFlexible
        p.isSleepFlexible    = isSleepFlexible
        p.isCannabisFlexible = isCannabisFlexible
        p.isKidsFlexible     = isKidsFlexible
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
    }
}

// MARK: - Background Edit Sheet

struct BackgroundEditSheet: View {
    @Environment(UserProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var ethnicities: Set<String> = []
    @State private var languages: Set<String> = []
    @State private var birthCountry = ""
    @State private var isSaving = false

    private static let ethnicityOptions = [
        "White", "Asian", "Hispanic/Latino", "Black/African American",
        "Native Hawaiian", "Pacific Islander", "Other+"
    ]
    private static let languageOptions = [
        "English", "Spanish", "Mandarin/Chinese", "Hindi", "Arabic",
        "French", "Portuguese", "Russian", "Japanese", "Korean",
        "German", "Vietnamese", "Italian", "Other+"
    ]
    private static let countries = StaticConfig.countries

    var body: some View {
        editNav(title: "Background", isSaving: isSaving, onCancel: { dismiss() }, onSave: save) {
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
        var p = ProfileUpdatePayload()
        p.ethnicity    = store.ethnicities.isEmpty ? nil : store.ethnicities
        p.languages    = store.languages.isEmpty   ? nil : store.languages
        p.birthCountry = birthCountry.isEmpty      ? nil : birthCountry
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
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
    @State private var isSaving = false

    private static let educationOptions = EducationLevel.allCases.map(\.displayName)
    private static let careerOptions    = CareerField.allCases.map(\.rawValue)

    private var isMandatoryFilled: Bool { !career.isEmpty && !education.isEmpty }

    var body: some View {
        editNav(title: "Career & Education", isSaving: isSaving, onCancel: { dismiss() }, onSave: save) {
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
                    Button {
                            guard unit != heightUnit else { return }
                            heightUnit = unit
                            if unit == "CM" { heightFt = ""; heightIn = "" }
                            else { heightCm = "" }
                        } label: {
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
        var p = ProfileUpdatePayload()
        p.careerField = career.isEmpty    ? nil : career
        p.education   = education.isEmpty ? nil : (EducationLevel.from(displayName: education)?.rawValue ?? education)
        p.jobTitle    = jobTitle.isEmpty  ? nil : jobTitle
        p.school      = school.isEmpty    ? nil : school
        let isImperial = heightUnit == "FT"
        if !heightFt.isEmpty || !heightCm.isEmpty {
            p.heightUnit = isImperial ? "imperial" : "metric"
            p.heightFt   = isImperial ? Int(heightFt) : nil
            p.heightIn   = isImperial ? (Int(heightIn) ?? 0) : nil
            p.heightCm   = isImperial ? nil : Int(heightCm)
        }
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
    }
}

// MARK: - Prompts Edit Sheet

struct PromptsEditSheet: View {
    @Environment(UserProfileStore.self) var store
    @Environment(\.dismiss) private var dismiss

    // Snapshot of prompt values on open — restored if user cancels without saving
    @State private var snapshot: (String, String, String, String, String, String, String, String)?
    @State private var isSaving = false

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
        @Bindable var store = store
        editNav(title: "Prompts", isSaving: isSaving, onCancel: { restoreSnapshot(); dismiss() }, onSave: save) {
            promptField("Prompt 1", question: $store.prompt1Question, answer: $store.prompt1Answer,
                        usedBy: [store.prompt2Question, store.prompt3Question])
            promptField("Prompt 2", question: $store.prompt2Question, answer: $store.prompt2Answer,
                        usedBy: [store.prompt1Question, store.prompt3Question])
            promptField("Prompt 3", question: $store.prompt3Question, answer: $store.prompt3Answer,
                        usedBy: [store.prompt1Question, store.prompt2Question])
            sectionLabel("Your own prompt")
            editField("Write your own question...", "", text: $store.customPromptQuestion)
            if !store.customPromptQuestion.isEmpty {
                editField("Your answer", "Write your answer...", text: $store.customPromptAnswer, multiline: true)
            }
        }
        .onAppear {
            snapshot = (
                store.prompt1Question, store.prompt1Answer,
                store.prompt2Question, store.prompt2Answer,
                store.prompt3Question, store.prompt3Answer,
                store.customPromptQuestion, store.customPromptAnswer
            )
        }
    }

    private func restoreSnapshot() {
        guard let s = snapshot else { return }
        store.prompt1Question = s.0; store.prompt1Answer = s.1
        store.prompt2Question = s.2; store.prompt2Answer = s.3
        store.prompt3Question = s.4; store.prompt3Answer = s.5
        store.customPromptQuestion = s.6; store.customPromptAnswer = s.7
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
        var promptList: [ProfileUpdatePayload.PromptEntry] = []
        if !store.prompt1Question.isEmpty && !store.prompt1Answer.isEmpty {
            promptList.append(.init(question: store.prompt1Question, answer: store.prompt1Answer))
        }
        if !store.prompt2Question.isEmpty && !store.prompt2Answer.isEmpty {
            promptList.append(.init(question: store.prompt2Question, answer: store.prompt2Answer))
        }
        if !store.prompt3Question.isEmpty && !store.prompt3Answer.isEmpty {
            promptList.append(.init(question: store.prompt3Question, answer: store.prompt3Answer))
        }
        if !store.customPromptQuestion.isEmpty && !store.customPromptAnswer.isEmpty {
            promptList.append(.init(question: store.customPromptQuestion, answer: store.customPromptAnswer))
        }
        var p = ProfileUpdatePayload()
        p.prompts = promptList.isEmpty ? nil : promptList
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
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
    @State private var isSaving = false

    var body: some View {
        editNav(title: "Preferences", isSaving: isSaving, onCancel: { dismiss() }, onSave: save) {
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
        var p = ProfileUpdatePayload()
        p.meetPreference         = meetPref.isEmpty ? nil : meetPref
        p.relationshipGoals      = store.relationshipGoals.isEmpty ? nil : store.relationshipGoals
        p.minAgePreference       = Int(minAge)
        p.maxAgePreference       = Int(maxAge)
        p.distancePreferenceMiles = Int(distance)
        isSaving = true
        Task {
            await store.patchProfile(p)
            if store.patchError == nil { dismiss() } else { isSaving = false }
        }
    }
}
