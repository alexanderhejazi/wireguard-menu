# WireGuard Menu

A small native macOS menu bar app for independent `wg-quick` tunnels, with a privileged helper for password-free tunnel control. No package dependencies.

Connect, disconnect, or reconnect individual tunnels from the menu bar. This is an independent project, not an official WireGuard application.

## Install

Requires macOS 13 or later and Homebrew's WireGuard tools:

```sh
brew install wireguard-tools wireguard-go
```

Download the universal DMG from [Releases](https://github.com/mnilsson/wireguard-menu/releases), open it, and drag **WireGuard Menu.app** onto **Applications**. Eject the disk image and open the app from `/Applications`. If no release is available yet, build from source below.

## Build from source

Requires macOS 13+, Swift 6+, Homebrew's `wireguard-tools` and `wireguard-go`, and an Apple code-signing identity in your keychain. The build uses the first available identity; set `SIGNING_IDENTITY` to select a different one. The app and helper must be signed by the same team.

```sh
git clone https://github.com/mnilsson/wireguard-menu.git
cd wireguard-menu
bash build.sh
ditto "dist/WireGuard Menu.app" "/Applications/WireGuard Menu.app"
open "/Applications/WireGuard Menu.app"
```

## Use

Click the network icon and choose **Enable password-free control…**. Approve WireGuard Menu under **System Settings → General → Login Items** (called **Login Items & Extensions** on some versions). macOS requires administrator approval for this initial setup. Subsequent Connect, Disconnect, Reconnect, and status checks use the helper without asking for your password. **Helper settings…** opens the same settings if approval is later revoked. **Launch at login** starts the menu bar app when you log in; tunnels are not reconnected automatically. Keep the app in `/Applications` so its bundled helper remains accessible after a restart. Distribution to other Macs additionally requires Developer ID signing and notarization.

Choose **Add tunnel…**, and select your `.conf` files. Export configurations from the WireGuard app first if needed; disconnect those profiles in that app and disable their on-demand activation before managing them here.

Each configuration needs a unique filename with 1–15 letters, digits, or `_ = + . -` characters before `.conf`. Adding a configuration copies it into `~/Library/Application Support/WireGuard Menu/Configurations/`. You can then delete the original, including from Downloads. Connect and Show in Finder use the imported copy; edits to the original do not affect it. Entries added with older versions still use their original paths: remove and re-add them to import a copy. Only select configurations you trust: `wg-quick` supports shell hooks that execute with administrator privileges.

The submenu for each tunnel provides Connect, Disconnect, and Reconnect actions, plus Show in Finder. Reconnect disconnects and then connects the tunnel again, including when it has already stopped. Disconnect and Reconnect remain available when status cannot be read. Quitting leaves tunnels running. Removing a stopped tunnel from the menu does not delete its configuration. The helper accepts requests only from this app signed by the same team, and only operates on `.conf` paths inside the requesting user's home directory. Re-add older configurations stored elsewhere to import them.

## Status and routing

The icon counts confirmed running tunnels. Status refreshes every three seconds and when opening the menu. The helper reads WireGuard's root-only status files. **Running** means the `wg-quick` mapping, matching control socket, and macOS network interface exist. It does not claim a recent handshake or remote service reachability. A missing or unavailable helper, or unreadable state, is shown as **Status unavailable**. This does not mean the tunnel is stopped; all connection actions remain available when no command is in progress.

This wraps the command-line tools, not profiles managed by the official WireGuard app. The app doesn't modify routes, keys, or DNS settings in configurations. For simultaneous office and AWS access, configure each tunnel's `AllowedIPs` for its destination networks. Overlapping networks/default routes and competing DNS settings need to be resolved in the configurations.

## Verify

```sh
swift test
```

To exercise connections, approve the helper, add real configurations, and use each tunnel's menu. Verify access to an office service and an AWS service with both tunnels running, then disconnect individually. These actions change networking. Tests cover configuration imports, status detection, command arguments, helper request validation, and rejection of XPC clients with the wrong signature without starting a tunnel.

GitHub Actions runs the tests and a release-mode compile on Apple Silicon and Intel for pull requests and pushes to `main`. Tests do not require an Apple signing identity or installed WireGuard tools. Pushing a `vX.Y.Z` tag runs a separate workflow that builds a universal app, signs and notarizes a DMG, and creates a draft GitHub release. See [RELEASING.md](RELEASING.md) for setup and release steps.

## Contributing

Issues and small, focused pull requests are welcome. Include reproduction steps for bugs and run `swift test` before submitting code changes. Do not include real tunnel configurations or private keys in issues or patches.

## License

[MIT](LICENSE), copyright Markus Nilsson. Separately installed WireGuard tools have their own licenses; see [THIRD_PARTY.md](THIRD_PARTY.md).
