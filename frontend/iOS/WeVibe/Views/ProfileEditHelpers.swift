import SwiftUI

// MARK: - Edit Nav Wrapper

func editNav<Content: View>(
    title: String,
    isSaving: Bool = false,
    onCancel: (() -> Void)? = nil,
    onSave: @escaping () -> Void,
    @ViewBuilder body: () -> Content
) -> some View {
    NavigationStack {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()
            ScrollView { VStack(spacing: 20) { body() }.padding(20) }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.secondaryBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if let onCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.white.opacity(isSaving ? 0.3 : 0.6))
                        .disabled(isSaving)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView().tint(AppTheme.iconColor)
                } else {
                    Button("Save", action: onSave).foregroundStyle(AppTheme.iconColor).fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Form field helpers

@ViewBuilder
func editField(_ title: String, _ placeholder: String, text: Binding<String>, multiline: Bool = false, keyboardType: UIKeyboardType = .default) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
        if multiline {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder).font(.system(size: 15)).foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 8).padding(.leading, 4)
                }
                TextEditor(text: text)
                    .font(.system(size: 15)).foregroundStyle(.white)
                    .scrollContentBackground(.hidden).frame(minHeight: 100)
            }
            .padding(12).background(Color.white.opacity(0.07)).cornerRadius(12)
        } else {
            TextField(placeholder, text: text)
                .font(.system(size: 15)).foregroundStyle(.white).tint(AppTheme.iconColor)
                .keyboardType(keyboardType)
                .autocorrectionDisabled(keyboardType == .URL)
                .textInputAutocapitalization(keyboardType == .URL ? .never : .sentences)
                .padding(14).background(Color.white.opacity(0.07)).cornerRadius(12)
        }
    }
}

@ViewBuilder
func pickerRow(_ title: String, selection: Binding<String>, options: [String]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
        Menu {
            Button("(none)") { selection.wrappedValue = "" }
            ForEach(options, id: \.self) { opt in Button(opt) { selection.wrappedValue = opt } }
        } label: {
            HStack {
                Text(selection.wrappedValue.isEmpty ? "Select..." : selection.wrappedValue)
                    .font(.system(size: 15))
                    .foregroundStyle(selection.wrappedValue.isEmpty ? .white.opacity(0.4) : .white)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(14).background(Color.white.opacity(0.07)).cornerRadius(12)
        }
    }
}

@ViewBuilder
func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
    HStack {
        Text(label).font(.system(size: 15)).foregroundStyle(.white)
        Spacer()
        Toggle("", isOn: isOn).tint(AppTheme.primaryButton)
    }
    .padding(14).background(Color.white.opacity(0.05)).cornerRadius(12)
}

@ViewBuilder
func sectionLabel(_ title: String) -> some View {
    Text(title.uppercased())
        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6)).tracking(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
}

@ViewBuilder
func infoNote(_ text: String) -> some View {
    Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04)).cornerRadius(10)
}

/// Section label with optional required asterisk
@ViewBuilder
func requiredLabel(_ title: String, required: Bool = true) -> some View {
    HStack(spacing: 2) {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6)).tracking(0.8)
        if required {
            Text("*").font(.system(size: 11, weight: .bold)).foregroundStyle(.red)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

/// Inline validation error shown below a field
@ViewBuilder
func validationError(_ message: String) -> some View {
    HStack(spacing: 4) {
        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 12))
        Text(message).font(.system(size: 12))
    }
    .foregroundStyle(.red)
}

// MARK: - Handle field (Instagram / TikTok)
// Shows a fixed "@" prefix, strips pasted URLs down to just the username,
// and restricts input to letters, numbers, underscores, and dots.

@ViewBuilder
func handleField(_ title: String, text: Binding<String>, maxLength: Int) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
        HStack(spacing: 0) {
            Text("@")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 14)
            TextField("username", text: text)
                .font(.system(size: 15)).foregroundStyle(.white).tint(AppTheme.iconColor)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .padding(.leading, 4).padding(.trailing, 14).padding(.vertical, 14)
                .onChange(of: text.wrappedValue) { _, new in
                    text.wrappedValue = sanitizeHandle(new, maxLength: maxLength)
                }
        }
        .background(Color.white.opacity(0.07)).cornerRadius(12)
    }
}

private func sanitizeHandle(_ input: String, maxLength: Int) -> String {
    var s = input.trimmingCharacters(in: .whitespaces)
    // Extract handle from a pasted URL
    let urlPrefixes = [
        "https://www.instagram.com/", "https://instagram.com/",
        "https://www.tiktok.com/@",   "https://tiktok.com/@",
        "https://www.tiktok.com/",    "https://tiktok.com/",
        "instagram.com/", "tiktok.com/@", "tiktok.com/",
    ]
    for prefix in urlPrefixes {
        if s.lowercased().hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
            break
        }
    }
    // Remove trailing path / query string from URL extracts
    s = s.components(separatedBy: "/").first ?? s
    s = s.components(separatedBy: "?").first ?? s
    // Strip a leading "@" if the user typed or pasted it
    if s.hasPrefix("@") { s = String(s.dropFirst()) }
    // Keep only valid handle characters (ASCII letters/digits, underscore, dot)
    s = s.filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" || $0 == "." }
    return s.count > maxLength ? String(s.prefix(maxLength)) : s
}
