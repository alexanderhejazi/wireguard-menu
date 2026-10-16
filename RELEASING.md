# Building for distribution

Automated releases are not configured. Pushing a version tag does not build or publish an app.

## Local builds

`bash build.sh` builds for the current Mac and defaults to version `0.1.0`, build `1`. To build a universal app for Apple Silicon and Intel:

```sh
VERSION=0.1.0 BUILD_NUMBER=1 bash build.sh --arch arm64 --arch x86_64
```

The app is written to `dist/WireGuard Menu.app`, with the project license and external-tool notices inside its bundle. WireGuard tools remain a separate Homebrew installation.

Set `SIGNING_IDENTITY` to a certificate name or fingerprint when you have multiple identities. Local builds are signed but are not automatically notarized or uploaded.

## Public distribution

Downloadable releases require Apple Developer Program membership, a **Developer ID Application** certificate with its private key, and notarization credentials for the same team. An **Apple Development** certificate can be used for local development but cannot be used for notarized releases. See [Apple's notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

Signed, notarized releases are deferred until those prerequisites are available. The repository's build/test CI does not need signing credentials.
