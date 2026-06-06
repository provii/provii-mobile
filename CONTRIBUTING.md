# Contributing to provii-mobile

This repository contains the Provii wallet mobile application for iOS and
Android, maintained by Maelstrom AI Pty Ltd. Contributions are welcome. This
guide covers setup, testing, conventions, and the pull request workflow.

## Development Setup

### Prerequisites

You need the toolchain for the platform you plan to work on.

| Platform | Toolchain |
|---|---|
| iOS | Xcode 15+, macOS, CocoaPods |
| Android | Android Studio, JDK 17, Gradle |
| Shared (Rust SDK) | Rust toolchain, cargo-ndk, UniFFI |

### Clone and install

```bash
git clone https://github.com/provii/provii-mobile.git
cd provii-mobile
```

#### iOS

```bash
cd ios
bundle install
bundle exec pod install
open ProviiWallet.xcworkspace
```

#### Android

Open the `android/` directory in Android Studio. Gradle will sync dependencies
automatically.

## Running Tests

### iOS

```bash
cd ios
xcodebuild test \
  -workspace ProviiWallet.xcworkspace \
  -scheme ProviiWallet \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Android

```bash
cd android

# Unit tests
./gradlew testDebugUnitTest

# Instrumented tests (requires emulator or device)
./gradlew connectedDebugAndroidTest
```

## Commit Conventions

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/)
format:

```
<type>(<scope>): <description>
```

Accepted types:

| Type | Use |
|---|---|
| `feat` | A new feature or capability |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `chore` | Build, CI, dependency updates |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |

Scope is optional but encouraged. Use the platform name when the change is
localised, e.g. `feat(ios): add credential detail animation` or
`fix(android): correct deep link parsing`.

Keep the subject line under 72 characters. Use the body for context on why the
change was made, not what was changed.

## Pull Request Process

1. Fork the repository and create a feature branch from `main`.
2. Make your changes. Keep commits atomic, one logical change per commit.
4. Run the relevant test suite and linter before pushing.
5. Open a pull request against `main` on `provii/provii-mobile`.

Your PR description should include a short summary of what changed and why, the
platform(s) affected (iOS, Android, or both), and how reviewers can verify the
behaviour. Screenshots or screen recordings help when the change is visual.

A maintainer will review your PR. Expect at least one round of feedback. CI must
pass before merge. If CI fails on something unrelated to your change, note it in
a comment so reviewers can distinguish.

## Coding Style

### Swift (iOS)

SwiftLint enforces the project style. The configuration lives in
`.swiftlint.yml`. Run SwiftLint locally before committing:

```bash
swiftlint lint --path ios/
```

### Kotlin (Android)

Detekt handles static analysis. Format code with ktlint. Android Studio's
default Kotlin formatter produces acceptable output for most cases.

### Language in comments and documentation

Use Australian English spelling in all comments, documentation, and user-facing
strings. That means `organisation`, `colour`, `licence` (noun), `defence`,
`behaviour`, `analyse`, `metre`, `centre`. If your editor's spellchecker flags
these, it is wrong.

## Contributor Licence Agreement

Before your first contribution can be merged, you must sign the project CLA. The
full text is in [CLA.md](CLA.md).

To sign, reply to your pull request with:

> I have read the CLA Document and I hereby sign the CLA

Your signature is recorded automatically. You only need to sign once across all
repositories in the organisation.
