import SwiftUI

// MARK: - PersonalityResult

struct PersonalityResult {
    let primary: PersonalityMeta
    let secondary: PersonalityMeta?

    var isHybrid: Bool { secondary != nil }
}

// MARK: - Helpers

/// Computes a PersonalityResult from raw quiz answer indices.
func calculatePersonalityResult(from answers: [Int]) -> PersonalityResult {
    let fallback = StaticConfig.personalityMeta.values.first!
    let letterMap = [0: "A", 1: "B", 2: "C", 3: "D"]

    guard !answers.isEmpty else {
        return PersonalityResult(primary: fallback, secondary: nil)
    }

    var counts = [0, 0, 0, 0]
    for answer in answers {
        if answer >= 0 && answer < 4 { counts[answer] += 1 }
    }

    let max1 = counts.max() ?? 0

    let topLetters = counts.enumerated()
        .filter { $0.element == max1 && $0.element > 0 }
        .compactMap { letterMap[$0.offset] }

    guard let primaryLetter = topLetters.first,
          let primary = StaticConfig.personalityMeta[primaryLetter]
    else {
        return PersonalityResult(primary: fallback, secondary: nil)
    }

    if topLetters.count >= 2,
       let secondary = StaticConfig.personalityMeta[topLetters[1]] {
        return PersonalityResult(primary: primary, secondary: secondary)
    } else {
        let sortedCounts = counts.enumerated().sorted { $0.element > $1.element }
        let max2 = sortedCounts[1].element
        if max1 - max2 <= 1 && max2 > 0,
           let secondaryLetter = letterMap[sortedCounts[1].offset],
           let secondary = StaticConfig.personalityMeta[secondaryLetter] {
            return PersonalityResult(primary: primary, secondary: secondary)
        }
    }

    return PersonalityResult(primary: primary, secondary: nil)
}

/// Builds a PersonalityResult from the key strings stored in UserProfileStore
/// (e.g. primaryKey = "B", secondaryKey = "D"). Returns nil if primaryKey is unrecognised.
func personalityResult(primaryKey: String, secondaryKey: String) -> PersonalityResult? {
    guard !primaryKey.isEmpty,
          let primary = StaticConfig.personalityMeta[primaryKey] else { return nil }
    let secondary = secondaryKey.isEmpty ? nil : StaticConfig.personalityMeta[secondaryKey]
    return PersonalityResult(primary: primary, secondary: secondary)
}

// MARK: - Info Tooltip

private struct PersonalityInfoTooltip: View {
    let text: String
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { isShowing = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 8)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1A3025").opacity(0.85))
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(hex: "#2A4A35"), lineWidth: 1)
            }
        }
        .frame(maxWidth: 260)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.85).combined(with: .opacity),
            removal:   .scale(scale: 0.9).combined(with: .opacity)
        ))
    }
}

// MARK: - Type Label with Info Button

/// Single personality type label — large bold name in brand color with an info tooltip.
/// Used inside PersonalityFullDisplay.
struct PersonalityTypeLabelView: View {
    let meta: PersonalityMeta
    @State private var showTooltip = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 8) {
                Text(meta.type)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(meta.color)
                    .multilineTextAlignment(.center)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showTooltip.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(meta.color.opacity(0.7))
                }
            }

            if showTooltip {
                PersonalityInfoTooltip(text: meta.description, isShowing: $showTooltip)
                    .offset(x: 20, y: 44)
                    .zIndex(10)
            }
        }
    }
}

// MARK: - Full Display (JoinQueue-style)

/// Full-size personality display: "you are a hybrid of X and Y" with large type labels and
/// info tooltips. Designed for dark backgrounds (JoinQueue, result screens).
/// Apply entrance animation modifiers (opacity, offset) at the call site.
struct PersonalityFullDisplay: View {
    let primaryKey: String
    let secondaryKey: String

    var body: some View {
        if let result = personalityResult(primaryKey: primaryKey, secondaryKey: secondaryKey) {
            VStack(spacing: 12) {
                if result.isHybrid, let secondary = result.secondary {
                    Text("you are a hybrid of")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))

                    PersonalityTypeLabelView(meta: result.primary)

                    Text("and")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.vertical, 2)

                    PersonalityTypeLabelView(meta: secondary)
                } else {
                    Text("you are a")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))

                    PersonalityTypeLabelView(meta: result.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Compact Badge (profile card style)

/// Compact inline personality badge: "hybrid of X  &  Y" on one line.
/// `labelColor` should match the surrounding card theme (dark or light).
struct PersonalityCompactBadge: View {
    let primaryKey: String
    let secondaryKey: String
    var labelColor: Color = .white.opacity(0.5)

    var body: some View {
        if let result = personalityResult(primaryKey: primaryKey, secondaryKey: secondaryKey) {
            VStack(alignment: .leading, spacing: 3) {
                if result.isHybrid, let secondary = result.secondary {
                    Text("hybrid of")
                        .font(.system(size: 12))
                        .foregroundStyle(labelColor)
                    (Text(result.primary.type).foregroundStyle(result.primary.color)
                        + Text("  &  ").foregroundStyle(labelColor)
                        + Text(secondary.type).foregroundStyle(secondary.color))
                        .font(.system(size: 16, weight: .bold))
                } else {
                    Text(result.primary.type)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(result.primary.color)
                }
            }
        }
    }
}
