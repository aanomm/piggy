# Security Policy

Piggy is a local macOS filesystem tool. Security issues matter because the tool inspects applications, launch agents, leftovers, and potentially user-controlled paths.

## Supported versions

Piggy is pre-1.0. Security fixes are applied to the main development branch until the first tagged release exists.

## Reporting a vulnerability

Until the public repository is finalized, report issues privately to the maintainer. After publication, this file should be updated with a private security contact or GitHub private vulnerability reporting.

Please include:

- affected command and version/commit;
- exact reproduction steps;
- whether the issue can delete, expose, or corrupt user data;
- relevant paths, with personal information redacted.

## Security posture

Piggy should remain:

- non-destructive by default;
- explicit before destructive actions;
- conservative around system, Apple-signed, and protected locations;
- clear about skipped files and partial cleanup;
- free of telemetry and network calls unless explicitly documented.

## High-risk areas

- Path traversal or unsafe path expansion.
- Following symlinks into unexpected locations.
- Removing files outside the app/support-file scope.
- Trusting bundle metadata from untrusted apps.
- Treating media/photo-library scanning as safe without explicit opt-in.
- Running shell commands from app names, bundle IDs, or user-provided paths.
