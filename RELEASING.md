# Releases

Pushing a tag such as `v0.1.0` runs [.github/workflows/release.yml](.github/workflows/release.yml). It tests the code, builds a universal macOS app (Apple Silicon and Intel), signs the app and helper, notarizes and staples the app, and attaches a ZIP to a **draft** GitHub release. The ZIP includes the project license and external-tool notices inside the app bundle. WireGuard tools remain a separate Homebrew installation.

## One-time setup

You need Apple Developer Program membership, a **Developer ID Application** certificate with its private key, and notarization credentials for the same team. An **Apple Development** certificate works for local development but cannot be used for these releases. See [Apple's notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [GitHub's signing setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).

In Keychain Access, export the Developer ID Application certificate **and its private key** as a password-protected `.p12` file. Add these repository secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded contents of the exported `.p12` file. |
| `P12_PASSWORD` | The password chosen when exporting that file. |
| `APPLE_ID` | The Apple Account email used for notarization. |
| `APPLE_TEAM_ID` | The developer team ID associated with the certificate. |
| `APPLE_APP_SPECIFIC_PASSWORD` | An [app-specific password](https://support.apple.com/en-us/102654) for that Apple Account. |

Use the repository settings UI or `gh secret set NAME --repo mnilsson/wireguard-menu` to enter each value. Keep the exported certificate outside this repository. The workflow imports it into a temporary keychain and removes the signing credentials after the job. Pull-request CI does not use these secrets.

## Cut a release

After merging the intended changes into `main` and checking that CI passes:

```sh
git switch main
git pull --ff-only
git tag v0.1.0
git push origin v0.1.0
```

Use the next unused `vX.Y.Z` tag. The tag sets the app's version; the Actions run number sets its build number. Watch the **Release** workflow, download the ZIP from the draft release, and test installation and Connect, Disconnect, and Reconnect on a Mac with the Homebrew tools installed. Publish the draft when it is ready.

If signing or notarization fails, fix the credentials or reported issue and rerun the failed workflow. A release is only created after signing, notarization, and Gatekeeper verification succeed. No unsigned fallback is published.

## Local builds

`bash build.sh` builds for the current Mac and defaults to version `0.1.0`, build `1`. To exercise the universal packaging locally:

```sh
VERSION=0.1.0 BUILD_NUMBER=1 bash build.sh --arch arm64 --arch x86_64
```

Set `SIGNING_IDENTITY` to a certificate name or fingerprint when you have multiple identities. Local builds are signed but are not automatically notarized or uploaded.
