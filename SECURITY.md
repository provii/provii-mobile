# Security Policy

## Overview

The Provii wallet mobile application handles age verification credentials using zero knowledge proofs. We take security vulnerabilities seriously and appreciate responsible disclosure of findings.

## Scope

The following are in scope for vulnerability reports:

- The iOS application (Swift source, dependencies, build pipeline)
- The Android application (Kotlin source, dependencies, build pipeline)
- The Rust wallet SDK (UniFFI bindings, cryptographic operations)
- CI/CD pipeline configuration and release signing
- Deep link validation and handling
- Keychain/Keystore integration and credential storage
- Documentation that could lead to insecure implementations

The following are out of scope:

- The sandbox environment and sandbox credentials (these are intentionally public)
- Third-party dependencies (report upstream)
- Social engineering attacks against maintainers
- Denial of service against development infrastructure
- Issues requiring physical access to an unlocked device

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

### For Critical or High Severity

Do not create a public GitHub issue. Email us at security@provii.app with a description of the vulnerability, steps to reproduce, potential impact, and any suggested fixes.

You can also create a [private security advisory](https://github.com/provii/provii-mobile/security/advisories/new) on GitHub.

### For Medium or Low Severity

Create a [private security advisory](https://github.com/provii/provii-mobile/security/advisories/new) on GitHub. Provide detailed reproduction steps and include any relevant code snippets or screenshots.

### Encrypted Communication

For sensitive vulnerability details, encrypt your email using our PGP public key. The key fingerprint and full public key are published at https://provii.app/.well-known/pgp-key.txt. You may also reach us via Signal at the number listed on that page.

### Response Timeline

| Stage | Timeline |
|-------|----------|
| Initial acknowledgement | Within 48 hours |
| Status update with triage | Within 5 business days |
| Critical severity fix | 24 to 72 hours |
| High severity fix | 7 days |
| Medium severity fix | 30 days |
| Low severity fix | 90 days |

### Coordinated Disclosure

We follow a 90-day coordinated disclosure window. If we have not resolved the issue within 90 days of your initial report, you may publicly disclose the vulnerability. We ask that you give us reasonable notice before public disclosure so we can coordinate the release of a fix.

## Safe Harbour

Maelstrom AI Pty Ltd will not pursue legal action against security researchers who act in good faith and within the scope defined above. Good faith means making a reasonable effort to avoid privacy violations, data destruction, and service disruption during your research. If you accidentally cause disruption, stop immediately and report it.

We consider security research conducted in accordance with this policy to be authorised under applicable computer fraud laws, and we will not initiate legal claims against researchers who comply with this policy.

## Security Measures

### Data Protection

All sensitive data is encrypted using platform-native secure storage (iOS Keychain, Android EncryptedSharedPreferences). Network communications require TLS 1.3. Production builds strip all debug logging. Cryptographic key material is zeroised after use.

### Authentication

Biometric authentication is supported via Face ID and Touch ID on iOS, and fingerprint and face unlock on Android. Cryptographic keys are stored in hardware security modules where available (Secure Enclave on iOS, StrongBox/TEE on Android). Sessions time out automatically and tokens are stored in secure storage.

### Code Security

Release builds use R8 on Android to remove unused code and obfuscate. All connections enforce TLS 1.3 through App Transport Security on iOS and network security config on Android. The app detects and warns users on compromised (rooted/jailbroken) devices. Certificate transparency is validated on all API connections.

### Build and Release Security

All releases are cryptographically signed. Build provenance is attested using Sigstore. Automated scanning detects vulnerable dependencies. Gitleaks scanning prevents accidental secret commits.

## Security Scanning

| Tool | Purpose | Schedule |
|------|---------|----------|
| Gitleaks | Secret detection | Every push/PR |
| Semgrep | Static analysis (Swift/Kotlin) | Every push/PR |
| CodeQL | Deep code analysis | Every push/PR |
| Dependabot | Dependency updates | Weekly |

## Secure Development Practices

### For Contributors

1. Never commit secrets. Use environment variables and secrets management.
2. Review dependencies. Verify new dependencies before adding them.
3. Follow OWASP Mobile Security Guidelines.
4. Include security tests in your PRs.

### Code Review Requirements

All code changes require security-focused code review, passing security scans, no new high or critical vulnerabilities, and accessibility verification.

## Compliance

The Provii wallet aims to comply with OWASP MASVS (Mobile Application Security Verification Standard), WCAG 2.2 (Web Content Accessibility Guidelines), the Apple App Store security requirements, and the Google Play security requirements.

## Contact

For security-related enquiries:

- Email: security@provii.app
- Security advisories: [GitHub Security Advisories](https://github.com/provii/provii-mobile/security/advisories)

For general support:

- Documentation: https://docs.provii.app
- Support: support@provii.app

## Acknowledgements

We thank all security researchers who responsibly disclose vulnerabilities. Contributors who report valid security issues will be acknowledged (with their permission) in our security hall of fame.
