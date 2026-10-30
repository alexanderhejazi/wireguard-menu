import Foundation
import XCTest
import WireGuardCore
@testable import ArchwayHelper

final class SplitDNSTests: XCTestCase {
    func testDNSLinesAreRemovedFromInterfaceSectionOnly() {
        let configuration = """
        [Interface]
        Address = 10.45.0.3/32
        dns = 10.1.0.2, Prd.Example.dev.  # comment
        DNS=fd00::53 corp.example
        PostUp = echo DNS = kept

        [Peer]
        DNS = 10.9.9.9
        AllowedIPs = 10.1.0.0/16
        """
        let (sanitized, dns) = extractDNS(from: configuration)
        XCTAssertEqual(dns, SplitDNS(servers: ["10.1.0.2", "fd00::53"], domains: ["prd.example.dev", "corp.example"]))
        XCTAssertEqual(sanitized, """
        [Interface]
        Address = 10.45.0.3/32
        PostUp = echo DNS = kept

        [Peer]
        DNS = 10.9.9.9
        AllowedIPs = 10.1.0.0/16
        """)
    }

    func testUnsafeValuesAreDropped() {
        let (_, dns) = extractDNS(from: "[Interface]\nDNS = 10.1.0.999, ../../etc/hosts, a/b, ok-domain\n")
        XCTAssertEqual(dns, SplitDNS(servers: [], domains: ["ok-domain"]))
    }

    func testResolversAreScopedToTunnelAndLeaveOtherFilesAlone() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "nameserver 127.0.0.1".write(to: directory.appendingPathComponent("test"), atomically: true, encoding: .utf8)
        let resolvers = ResolverFiles(directory: directory)

        resolvers.install(SplitDNS(servers: ["10.1.0.2"], domains: ["prd.example.dev", "test"]), tunnel: "aws-prd")
        resolvers.install(SplitDNS(servers: ["10.44.0.1"], domains: ["prd.example.dev", "stg.example.dev"]), tunnel: "aws-stg")
        resolvers.install(SplitDNS(servers: ["10.44.0.1"], domains: []), tunnel: "no-domain")

        let read = { (name: String) in try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) }
        XCTAssertEqual(read("prd.example.dev"), "# Managed by Archway for tunnel aws-prd\nnameserver 10.1.0.2\n")
        XCTAssertEqual(read("stg.example.dev"), "# Managed by Archway for tunnel aws-stg\nnameserver 10.44.0.1\n")
        XCTAssertEqual(read("test"), "nameserver 127.0.0.1")

        resolvers.remove(tunnel: "aws-prd")
        XCTAssertNil(read("prd.example.dev"))
        XCTAssertNotNil(read("stg.example.dev"))

        resolvers.removeStale { $0 == "aws-stg" ? .unknown : .stopped }
        XCTAssertNotNil(read("stg.example.dev"))
        resolvers.removeStale { _ in .stopped }
        XCTAssertNil(read("stg.example.dev"))
        XCTAssertEqual(read("test"), "nameserver 127.0.0.1")
    }

    func testWGQuickReceivesCopyWithoutDNSAndResolversFollowTunnel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let resolverDirectory = root.appendingPathComponent("resolver")
        let runtime = root.appendingPathComponent("runtime")
        try FileManager.default.createDirectory(at: resolverDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("aws-prd.conf").path
        try "[Interface]\nDNS = 10.1.0.2, prd.example.dev\n".write(toFile: path, atomically: true, encoding: .utf8)
        let resolvers = ResolverFiles(directory: resolverDirectory)
        let resolver = resolverDirectory.appendingPathComponent("prd.example.dev").path

        var received: (path: String, contents: String?, permissions: Int?)?
        let up = runWGQuick("up", path: path, runtimeDirectory: runtime, resolvers: resolvers) { copy in
            received = (copy, try? String(contentsOfFile: copy, encoding: .utf8),
                        (try? FileManager.default.attributesOfItem(atPath: copy))?[.posixPermissions] as? Int)
            return CommandResult(code: 0, output: "")
        }
        XCTAssertEqual(up.code, 0)
        XCTAssertEqual(received?.path, runtime.appendingPathComponent("aws-prd.conf").path)
        XCTAssertEqual(received?.contents, "[Interface]\n")
        XCTAssertEqual(received?.permissions, 0o600)
        XCTAssertFalse(FileManager.default.fileExists(atPath: received!.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolver))

        _ = runWGQuick("down", path: path, runtimeDirectory: runtime, resolvers: resolvers,
                       status: { _ in .running("utun4") }) { _ in CommandResult(code: 1, output: "") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolver))
        _ = runWGQuick("down", path: path, runtimeDirectory: runtime, resolvers: resolvers,
                       status: { _ in .stopped }) { _ in CommandResult(code: 1, output: "") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: resolver))
    }
}
