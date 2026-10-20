import Foundation

struct Release: Decodable {
    let tagName: String
    let htmlURL: URL
    var version: String { tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

enum UpdateChecker {
    static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    static let upgradeCommand = "brew upgrade --cask wireguard-menu"
    static var installedWithHomebrew: Bool {
        ["/opt/homebrew", "/usr/local"].contains {
            FileManager.default.fileExists(atPath: "\($0)/Caskroom/wireguard-menu")
        }
    }

    /// Drafts and prereleases are excluded by GitHub's latest-release endpoint.
    static func latestRelease() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/mnilsson/wireguard-menu/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Release.self, from: data)
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        current.compare(candidate, options: .numeric) == .orderedAscending
    }
}
