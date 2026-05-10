# Repository Guidelines

## Project Structure & Module Organization

This is a Swift Package Manager macOS app named `LocalAuthenticator`.

- `Package.swift` declares the executable target and macOS 13 minimum.
- `Sources/LocalAuthenticator/LocalAuthenticatorApp.swift` is the app entry point.
- `Sources/LocalAuthenticator/Models/` contains OTP data types such as `OTPAccount` and `OTPAlgorithm`.
- `Sources/LocalAuthenticator/Services/` contains parsing, Base32 decoding, TOTP generation, Keychain persistence, and account-store logic.
- `Sources/LocalAuthenticator/Views/` contains SwiftUI views.
- `SupportingFiles/` contains app metadata and sandbox entitlements for Xcode packaging.

There is no test target yet. Add tests under `Tests/LocalAuthenticatorTests/` when introducing coverage.

## Build, Test, and Development Commands

- `swift build` builds the Swift package from the command line.
- `swift run LocalAuthenticator` builds and launches the executable target.
- `swift test` runs tests once a test target exists.
- Open `Package.swift` in Xcode, select the `LocalAuthenticator` scheme, and run the app for normal SwiftUI development.

For a sandboxed distributable app, use the README workflow: create a macOS App project, copy `Sources/LocalAuthenticator`, include `SupportingFiles/Info.plist`, and enable App Sandbox with Camera entitlement.

## Coding Style & Naming Conventions

Use standard Swift API Design Guidelines. Keep 4-space indentation, braces on the same line, and prefer small focused types by layer: views in `Views`, persistence and crypto helpers in `Services`, and plain data models in `Models`.

Name SwiftUI views with a `View` suffix, stores with a `Store` suffix, and errors with an `Error` suffix. Preserve existing French user-facing copy unless the change explicitly updates localization.

No formatter or linter configuration is present, so rely on Xcode formatting and keep diffs minimal.

## Testing Guidelines

Use XCTest for new tests. Prioritize deterministic service tests before UI tests, especially for:

- `TOTPGenerator` using RFC 6238 vectors.
- `Base32.decode` valid and invalid secrets.
- `OTPAuthParser` URI parsing edge cases.

Name tests after behavior, for example `testGeneratesSHA1CodeFromRFCVector()`.

## Commit & Pull Request Guidelines

This checkout does not include `.git`, so local commit history is unavailable. Use short, imperative commit messages such as `Add RFC6238 TOTP tests` or `Fix Keychain decode error handling`.

Pull requests should include a concise description, commands run (`swift build`, `swift test`), screenshots for visible SwiftUI changes, and notes for any security-sensitive behavior.

## Security & Configuration Tips

Never log `otpauth://` URIs, Base32 secrets, or generated account payloads. Keep secrets in Keychain-backed flows, not `UserDefaults`, files, or debug output. Preserve camera usage descriptions and sandbox entitlements when moving files into an Xcode app project.
