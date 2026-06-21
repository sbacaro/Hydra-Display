# Security Policy

## Supported versions

Hydra Display is an early-stage project. Security fixes are applied to the latest
released version and the `main` branch only.

| Version | Supported |
| ------- | --------- |
| 0.1.x   | ✅        |
| < 0.1   | ❌        |

## Reporting a vulnerability

Please **do not** open a public issue for security-sensitive reports.

Instead, use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
("Report a vulnerability" under the repository's **Security** tab), or contact the
maintainers privately. We aim to acknowledge reports within a reasonable time frame
and will coordinate a fix and disclosure with you.

When reporting, please include:

- A description of the issue and its impact
- Steps to reproduce
- The macOS and app version you tested

## Important context: private API & sandboxing

Hydra Display intentionally makes trade-offs that are relevant to security review:

- **Private API usage.** Virtual-display creation relies on undocumented Apple
  CoreGraphics classes (`CGVirtualDisplay` and friends). These are not covered by any
  public SDK contract and may change between macOS releases. See
  [docs/PRIVATE_API.md](docs/PRIVATE_API.md).
- **App Sandbox is disabled.** The virtual-display API is unavailable inside the
  sandbox, so the app ships unsandboxed. This is a deliberate, documented decision.
- **No notarization / ad-hoc signing.** Because the app uses a private API and ships
  without an Apple Developer ID, it is not notarized. Users must clear Gatekeeper
  quarantine manually (see the README).

These are design constraints rather than vulnerabilities, but we welcome reports that
identify ways to reduce the attack surface or harden the app within them.
