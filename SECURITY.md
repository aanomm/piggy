# Security Policy

Piggy is a local macOS filesystem tool. Security issues matter because the tool inspects applications, launch agents, and user-selected folders, and because a small set of commands can move user-approved files to Trash.

## Supported versions

Piggy is pre-1.0. Security fixes are applied to the main development branch until the first tagged release exists.

## Reporting a vulnerability

Please use GitHub private vulnerability reporting for the public repository:

<https://github.com/aanomm/piggy/security/advisories/new>

Please include:

- affected command and version/commit;
- exact reproduction steps;
- whether the issue can delete, expose, or corrupt user data;
- relevant paths, with personal information redacted.

## Safety model

Piggy should remain a review-first tool:

- read-only commands may scan apps/folders and update Piggy's local cache, but they must not move, edit, or delete user files;
- destructive commands must be explicit and confirmation-gated unless a force flag clearly says otherwise;
- system apps, Apple-protected locations, and ambiguous ownership should fail closed;
- skipped files and partial cleanup must be reported, not hidden;
- terminal output should distinguish observed facts from suggestions;
- JSON output should be stable enough for agents/scripts without requiring table scraping.

## Security posture

Piggy should remain:

- non-destructive by default;
- explicit before destructive actions;
- conservative around system, Apple-signed, and protected locations;
- clear about skipped files and partial cleanup;
- free of telemetry and network calls unless explicitly documented;
- privacy-scoped: broad scans of personal folders must be opt-in and path-explicit.

## High-risk areas

- Path traversal or unsafe path expansion.
- Following symlinks into unexpected locations.
- Removing files outside the app/support-file scope.
- Trusting bundle metadata from untrusted apps.
- Treating media/photo-library scanning as safe without explicit opt-in.
- Running shell commands from app names, bundle IDs, or user-provided paths.
- Agent workflows that turn Piggy's review output into unapproved cleanup actions.

## Non-goals

Piggy is not a malware scanner, notarization verifier, endpoint security product, or automatic Mac cleaner. It can surface clues worth reviewing, but it should not overclaim trust, safety, or removability.
