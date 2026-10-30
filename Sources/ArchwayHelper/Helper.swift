import Foundation
import WireGuardCore

final class HelperSession: NSObject, WireGuardHelperProtocol {
    let home: URL
    let commands: DispatchQueue
    let resolvers: ResolverFiles
    let runtimeDirectory: URL

    init(home: URL, commands: DispatchQueue, resolvers: ResolverFiles = ResolverFiles(),
         runtimeDirectory: URL = URL(fileURLWithPath: "/var/run/archway", isDirectory: true)) {
        self.home = home
        self.commands = commands
        self.resolvers = resolvers
        self.runtimeDirectory = runtimeDirectory
    }

    func statuses(_ paths: [String], withReply reply: @escaping @Sendable (Data) -> Void) {
        let statuses = Dictionary(paths.map { path in
            (path, validateConfigurationPath(path, home: home) ? Tunnel(path: path).status() : .unknown)
        }, uniquingKeysWith: { first, _ in first })
        reply((try? JSONEncoder().encode(statuses)) ?? Data())
        commands.async { [resolvers] in resolvers.removeStale() }
    }

    func change(_ path: String, action: String, withReply reply: @escaping @Sendable (Int32, String) -> Void) {
        guard let action = TunnelAction(rawValue: action), validateConfigurationPath(path, home: home) else {
            reply(-1, "Select a .conf file inside your home folder and use Connect, Disconnect, or Reconnect.")
            return
        }
        let resolvers = resolvers, runtimeDirectory = runtimeDirectory
        commands.async {
            guard let executable = ["/opt/homebrew/bin/wg-quick", "/usr/local/bin/wg-quick"]
                .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                reply(-1, "Install wireguard-tools and wireguard-go with Homebrew.")
                return
            }
            let run = { (command: String) in
                runWGQuick(command, path: path, runtimeDirectory: runtimeDirectory, resolvers: resolvers) { configuration in
                    runCommand("/usr/bin/env", arguments: [
                        "-i", "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                        "HOME=/var/root", executable, command, configuration
                    ])
                }
            }
            let result = action == .reconnect
                ? reconnectTunnel(status: { Tunnel(path: path).status() }, run: run)
                : run(action.rawValue)
            reply(result.code, result.output)
        }
    }
}

/// Runs wg-quick on a copy of the configuration without DNS lines, and applies its DNS as per-domain resolvers instead.
func runWGQuick(_ command: String, path: String, runtimeDirectory: URL, resolvers: ResolverFiles,
                status: (Tunnel) -> TunnelStatus = { $0.status() },
                run: (String) -> CommandResult) -> CommandResult {
    let tunnel = Tunnel(path: path)
    let copy = runtimeDirectory.appendingPathComponent(tunnel.name + ".conf")
    let dns: SplitDNS
    do {
        let extracted = extractDNS(from: try String(contentsOfFile: path, encoding: .utf8))
        dns = extracted.dns
        try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try? FileManager.default.removeItem(at: copy)
        // The copy keeps the original filename because wg-quick derives the interface name from it.
        guard FileManager.default.createFile(atPath: copy.path, contents: Data(extracted.configuration.utf8),
                                             attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
    } catch {
        return CommandResult(code: -1, output: "Could not prepare \(tunnel.name).conf: \(error.localizedDescription)")
    }
    defer { try? FileManager.default.removeItem(at: copy) }
    let result = run(copy.path)
    if command == TunnelAction.up.rawValue, result.code == 0 {
        resolvers.install(dns, tunnel: tunnel.name)
    } else if command == TunnelAction.down.rawValue, status(tunnel) == .stopped {
        resolvers.remove(tunnel: tunnel.name)
    }
    return result
}

func reconnectTunnel(status: () -> TunnelStatus, run: (String) -> CommandResult) -> CommandResult {
    let disconnected = run("down")
    // wg-quick down also fails when the tunnel has already disappeared.
    guard disconnected.code == 0 || status() == .stopped else { return disconnected }
    return run("up")
}

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    let clientRequirement: String
    let commands = DispatchQueue(label: "se.mnilsson.archway.commands")

    init(clientRequirement: String) { self.clientRequirement = clientRequirement }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard let user = getpwuid(connection.effectiveUserIdentifier),
              connection.effectiveUserIdentifier != 0 else { return false }
        let home = URL(fileURLWithPath: String(cString: user.pointee.pw_dir), isDirectory: true)
        connection.setCodeSigningRequirement(clientRequirement)
        connection.exportedInterface = NSXPCInterface(with: WireGuardHelperProtocol.self)
        connection.exportedObject = HelperSession(home: home, commands: commands)
        connection.resume()
        return true
    }
}

@main
struct ArchwayHelper {
    static func main() throws {
        guard geteuid() == 0 else { exit(1) }
        let delegate = HelperDelegate(clientRequirement: try HelperService.peerRequirement(identifier: HelperService.appIdentifier))
        let listener = NSXPCListener(machServiceName: HelperService.name)
        listener.delegate = delegate
        listener.resume()
        withExtendedLifetime(delegate) { RunLoop.current.run() }
    }
}
