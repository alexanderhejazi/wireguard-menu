import Foundation
import WireGuardCore

/// Per-domain resolvers in `/etc/resolver`, so only a tunnel's own domains are looked up through it.
struct ResolverFiles: Sendable {
    static let marker = "# Managed by Archway for tunnel "
    var directory = URL(fileURLWithPath: "/etc/resolver", isDirectory: true)

    func install(_ dns: SplitDNS, tunnel: String) {
        remove(tunnel: tunnel)
        guard !dns.servers.isEmpty, !dns.domains.isEmpty else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o755])
        let contents = Self.marker + tunnel + "\n" + dns.servers.map { "nameserver \($0)\n" }.joined()
        for domain in dns.domains {
            let file = directory.appendingPathComponent(domain)
            // Leave resolvers created by other tools or tunnels alone.
            guard !FileManager.default.fileExists(atPath: file.path) else { continue }
            try? contents.write(to: file, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        }
    }

    func remove(tunnel: String) {
        for (file, owner) in owners() where owner == tunnel {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Removes resolvers left behind by tunnels that stopped without Archway, for example across a restart.
    func removeStale(status: (String) -> TunnelStatus = { Tunnel(path: "/" + $0 + ".conf").status() }) {
        for (file, owner) in owners() where status(owner) == .stopped {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func owners() -> [(URL, String)] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { file in
            guard let first = (try? String(contentsOf: file, encoding: .utf8))?
                .split(separator: "\n", maxSplits: 1).first,
                  first.hasPrefix(Self.marker) else { return nil }
            return (file, String(first.dropFirst(Self.marker.count)))
        }
    }
}
