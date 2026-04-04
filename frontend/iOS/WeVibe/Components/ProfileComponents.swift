import SwiftUI
import UIKit

// MARK: - InterestChipView

struct InterestChipView: View {
    let text: String
    let colorIndex: Int

    private static let palette: [Color] = [
        Color(hex: "#E8927C"), Color(hex: "#3DCCC7"),
        Color(hex: "#6BCB77"), Color(hex: "#957DAD"), Color(hex: "#F6C344"),
    ]
    private var chipColor: Color { Self.palette[colorIndex % Self.palette.count] }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(chipColor)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(chipColor.opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(chipColor.opacity(0.35), lineWidth: 1))
            .clipShape(Capsule())
    }
}

// MARK: - BinarySlider
// A custom three-position slider: left option — neutral (empty) — right option.
// Pass options as [leftLabel, "", rightLabel]. Middle slot represents no preference.

struct BinarySlider: View {
    let title: String
    let options: [String]           // exactly 3 elements; middle should be ""
    @Binding var selection: String

    private var selectedIndex: Int {
        guard options.count == 3 else { return 0 }
        if let i = options.firstIndex(of: selection), !selection.isEmpty { return i }
        return 1  // default to middle (neutral)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            GeometryReader { geo in
                let w = geo.size.width
                let third = w / 3

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.07))

                    // Sliding thumb — hidden when neutral (middle)
                    if selectedIndex != 1 {
                        Capsule()
                            .fill(AppTheme.buttonGradient)
                            .frame(width: third)
                            .offset(x: third * CGFloat(selectedIndex))
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedIndex)
                    }

                    // Labels
                    HStack(spacing: 0) {
                        ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                            Button {
                                // Tapping current non-neutral selection → go neutral; else select
                                if !opt.isEmpty {
                                    selection = (selection == opt) ? "" : opt
                                } else {
                                    selection = ""
                                }
                            } label: {
                                Text(opt)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(
                                        (!opt.isEmpty && selection == opt) ? .black : .white.opacity(0.5)
                                    )
                                    .frame(width: third)
                                    .frame(maxHeight: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 42)
                .clipShape(Capsule())
            }
            .frame(height: 42)
        }
    }
}

// MARK: - SocialBadge

struct SocialBadge: View {
    enum Platform {
        case instagram(String)
        case tiktok(String)
        case spotify(String)   // full URL

        var displayHandle: String {
            switch self {
            case .instagram(let h): return "@\(h)"
            case .tiktok(let h):    return "@\(h)"
            case .spotify:          return "My Playlist"
            }
        }

        var appURL: URL? {
            switch self {
            case .instagram(let h): return URL(string: "instagram://user?username=\(h)")
            case .tiktok(let h):    return URL(string: "tiktok://user?name=\(h)")
            case .spotify(let url):
                // Convert https://open.spotify.com/playlist/ID → spotify:playlist:ID
                if let u = URL(string: url),
                   let host = u.host, host.contains("spotify"),
                   u.pathComponents.count >= 3 {
                    let type = u.pathComponents[1]
                    let id   = u.pathComponents[2].components(separatedBy: "?").first ?? u.pathComponents[2]
                    return URL(string: "spotify:\(type):\(id)")
                }
                return nil
            }
        }
        var webURL: URL {
            switch self {
            case .instagram(let h): return URL(string: "https://www.instagram.com/\(h)")!
            case .tiktok(let h):    return URL(string: "https://www.tiktok.com/@\(h)")!
            case .spotify(let url): return URL(string: url) ?? URL(string: "https://open.spotify.com")!
            }
        }
    }

    let platform: Platform

    @AppStorage("profileCardLightTheme") private var isLightTheme: Bool = false
    private var labelColor: Color   { isLightTheme ? Color(hex: "#1C1C1E") : .white }
    private var arrowColor: Color   { isLightTheme ? Color(hex: "#6C6C70") : .white.opacity(0.45) }
    private var tiktokCenter: Color { isLightTheme ? Color(hex: "#1C1C1E") : .white }
    private var tiktokBg: Color     { isLightTheme ? Color(hex: "#E5E5EA") : .white.opacity(0.08) }
    private var igBgOpacity: Double { isLightTheme ? 0.18 : 0.25 }
    private static let spotifyGreen = Color(hex: "#1DB954")

    var body: some View {
        Button {
            let target = platform.appURL.flatMap {
                UIApplication.shared.canOpenURL($0) ? $0 : nil
            } ?? platform.webURL
            UIApplication.shared.open(target)
        } label: {
            HStack(spacing: 7) {
                platformIcon
                Text(platform.displayHandle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(labelColor)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(arrowColor)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(platformBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var platformIcon: some View {
        switch platform {
        case .instagram:
            ZStack {
                RoundedRectangle(cornerRadius: 3.5)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#833AB4"), Color(hex: "#FD1D1D"), Color(hex: "#F77737")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 14, height: 14)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#833AB4"), Color(hex: "#FD1D1D"), Color(hex: "#F77737")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: 7.5, height: 7.5)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#833AB4"), Color(hex: "#F77737")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: 3.5, y: -3.5)
            }
            .frame(width: 16, height: 16)
        case .tiktok:
            ZStack {
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#69C9D0"))
                    .offset(x: -1.5, y: 1.5)
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#EE1D52"))
                    .offset(x: 1.5, y: -1.5)
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tiktokCenter)
            }
            .frame(width: 16)
        case .spotify:
            Image(systemName: "music.note.list")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.spotifyGreen)
        }
    }

    @ViewBuilder private var platformBackground: some View {
        switch platform {
        case .instagram:
            LinearGradient(
                colors: [
                    Color(hex: "#833AB4").opacity(igBgOpacity),
                    Color(hex: "#FD1D1D").opacity(igBgOpacity * 0.7),
                    Color(hex: "#F77737").opacity(igBgOpacity * 0.7),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .tiktok:
            tiktokBg
        case .spotify:
            Self.spotifyGreen.opacity(isLightTheme ? 0.12 : 0.15)
        }
    }
}
