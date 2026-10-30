import Foundation
import Darwin

/// DNS settings from a configuration's `[Interface]` section, applied per domain instead of system-wide.
public struct SplitDNS: Equatable, Sendable {
    public init(servers: [String] = [], domains: [String] = []) {
        self.servers = servers
        self.domains = domains
    }
    public var servers: [String]
    public var domains: [String]
}

/// Removes `DNS =` lines from the `[Interface]` section, parsed like wg-quick does.
/// wg-quick applies DNS to every network service and rewrites it on each route change, so it never receives them.
public func extractDNS(from configuration: String) -> (configuration: String, dns: SplitDNS) {
    var kept: [Substring] = []
    var dns = SplitDNS()
    var interfaceSection = false
    for line in configuration.split(separator: "\n", omittingEmptySubsequences: false) {
        let stripped = line.prefix { $0 != "#" }
        let key = stripped.prefix { $0 != "=" }.trimmingCharacters(in: .whitespaces)
        if key.hasPrefix("[") { interfaceSection = key.caseInsensitiveCompare("[Interface]") == .orderedSame }
        guard interfaceSection, key.caseInsensitiveCompare("DNS") == .orderedSame else {
            kept.append(line)
            continue
        }
        guard let separator = stripped.firstIndex(of: "=") else { continue }
        for value in stripped[stripped.index(after: separator)...]
            .split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init) {
            if value.range(of: #"^[0-9.]+$"#, options: .regularExpression) != nil || value.contains(":") {
                if isIPAddress(value) { dns.servers.append(value) }
            } else {
                let domain = value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
                if domain.range(of: #"^[a-z0-9_-]+(\.[a-z0-9_-]+)*$"#, options: .regularExpression) != nil {
                    dns.domains.append(domain)
                }
            }
        }
    }
    return (kept.joined(separator: "\n"), dns)
}

private func isIPAddress(_ value: String) -> Bool {
    var v4 = in_addr(), v6 = in6_addr()
    return inet_pton(AF_INET, value, &v4) == 1 || inet_pton(AF_INET6, value, &v6) == 1
}
