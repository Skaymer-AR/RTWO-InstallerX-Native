# Security policy

## Scope

This project intentionally weakens Android package-signature enforcement on a
single laboratory device. Reports about unintended privilege expansion,
bootloops, installer routing, SELinux labeling or unsafe recovery behavior are
in scope.

## Operational rules

- Keep the DISABLE ZIP on external storage.
- Never run Thanox Zygisk together with the patched `system_server` setup used here.
- Verify APK origin and hashes manually.
- Do not use this stack on a banking/identity device.
- Do not publish device dumps, package databases, keys or proprietary framework binaries.
