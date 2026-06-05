# Piggy

Piggy is a native macOS command-line tool for seeing what is taking up space: apps, folders, images, videos, and docs.

Its product soul is simple: **Show me the shit on my Mac — and make it easy to see.** Piggy is intentionally non-destructive by default. Scan commands may update Piggy’s local cache, but they do not delete apps or support files. Destructive actions are explicit, confirmation-gated, and backed by safety checks.

```bash
piggy sniff
piggy sniff apps
piggy sniff imgs ~/Pictures
piggy snort docs ~/Documents
piggy search docs tax ~/Documents
piggy stye ~/Downloads
```

Piggy’s noob-friendly command map is:

```text
piggy [action] [what] [where]
```

Actions: `sniff`, `snort`, `search`, `stye`.
What: `apps`, `imgs`, `vids`, `docs`.

## Why Piggy exists

macOS app cleanup is weird: an app bundle can be huge, Intel-only, quarantined, Apple-signed, App Store managed, or surrounded by background helpers. Most cleaners flatten those differences into a scary “delete this” button.

Piggy’s job is calmer:

- show what is actually taking space;
- explain why something deserves review;
- keep Apple/system apps protected;
- surface background agents and trust clues;
- make cleanup auditable instead of vibes-based.

## Current features

- Noob-friendly command architecture: `piggy [action] [what] [where]`
- Core actions: `sniff`, `snort`, `search`, and `stye`
- Four-letter what words: `apps`, `imgs`, `vids`, `docs`
- Folder size audit with recursive file counts: `piggy sniff` / `piggy stye ~/Downloads`
- App scanner for `/Applications`, `/System/Applications`, and `~/Applications`
- Image/video/document file scanning in user-chosen folders
- Size, architecture, origin, quarantine, and background-agent detection for apps
- Compact human tables plus JSON output for agents and scripts
- Safety-classified removal planning
- Confirmation-based deletion flow for user-approved cleanup
- Terminal splash menu and interactive browser
- Swift Package Manager test suite

## Example audit

```text
🐷 Piggy Mac Audit
──────────────────
Scope: non-destructive scan of macOS .app bundles
Disk:  Combined on-disk size of the scanned .app bundles.

Total apps                    237
Total app disk                61.08 GB
Apple apps                    65
3rd Party apps                172
App Store apps                26
Rosetta apps                  5
32-bit apps                   0
Unknown architecture          10
Quarantined apps              35
Apps with background agents   2
```

`Total app disk` is the sum of the on-disk sizes of all scanned `.app` bundles. It is not whole-disk usage and does not include every media/download/cache file on the Mac.

## Example folder audit

```text
🐷 Piggy Folder Audit
─────────────────────
Scope: non-destructive scan of folders under ~/Downloads
Disk:  Combined size of each folder's visible contents.
Files: Regular files counted recursively inside each folder.

#   Size         Files    Folders  Folder
────────────────────────────────────────────
1.  14.2 GB      18420    42       ComfyUI
2.  8.6 GB       31       3        video-renders
```

Useful folder scans:

```bash
piggy folders ~/Downloads --limit 25
piggy folders ~/Library --min-size 1gb
piggy folders . --depth 2 --min-size 500mb
```

By default Piggy skips hidden files/folders and ranks immediate child folders. Use `--include-hidden` and `--depth` only when you want a noisier scan.

## Install

Piggy does not have a Homebrew tap or signed binary release yet. For now, install from source with Swift Package Manager:

Requirements:

- macOS 14+
- Swift 6 toolchain / Xcode command line tools

```bash
git clone https://github.com/aanomm/piggy.git
cd piggy
swift build -c release
sudo install -m 755 .build/release/piggy /usr/local/bin/piggy
piggy --help
```

If you prefer not to use `sudo`, install to a user-owned bin directory that is already on your `PATH`:

```bash
mkdir -p ~/.local/bin
install -m 755 .build/release/piggy ~/.local/bin/piggy
~/.local/bin/piggy --help
```

Planned release path: first tagged GitHub release, then a Homebrew formula/tap once the CLI surface is stable.

For local development without installing globally:

```bash
swift run piggy sniff
swift run piggy sniff imgs ~/Pictures
swift run piggy search docs tax ~/Documents
```

## Development

```bash
swift test
swift build -c release
```

The core scanner and safety logic live in `PiggyKit` so behavior can be tested independently from the terminal UI.

Useful project docs:

- [`docs/architecture.md`](docs/architecture.md) — package layout, safety boundaries, and roadmap.
- [`docs/performance.md`](docs/performance.md) — local benchmark fixture and optimization notes.
- [`docs/terminal-design.md`](docs/terminal-design.md) — CLI design/accessibility principles.
- [`docs/agent-workflows.md`](docs/agent-workflows.md) — safe Codex/agent usage patterns and JSON examples.
- [`docs/codex-for-oss-readiness.md`](docs/codex-for-oss-readiness.md) — Codex for Open Source submission notes.

## Accessibility and terminal output

Piggy treats terminal output as UI:

- color is disabled automatically when stdout is not a TTY;
- `NO_COLOR=1` disables ANSI color;
- `PIGGY_COLOR=always` or `PIGGY_COLOR=never` can override color behavior;
- scan animation is skipped for non-interactive output so logs stay clean.

## Safety model

Piggy treats cleanup as a safety problem, not just a filesystem operation.

- `piggy mac audit`, `list`, `info`, `search`, `folders`, and `export` are non-destructive; scans may refresh Piggy’s local cache.
- System applications are blocked from deletion.
- Related files are classified before removal.
- Sensitive or ambiguous files are skipped and reported rather than silently removed.
- Destructive actions require confirmation unless the user explicitly passes force flags.

See [`SECURITY.md`](SECURITY.md) for vulnerability reporting and security posture.

## Roadmap

Near-term quality gates:

- public GitHub repository with CI required on pull requests;
- first tagged release artifact;
- installation docs via Homebrew or signed release artifact;
- media scanning commands behind privacy-safe, opt-in directory scopes.

Media roadmap:

- `piggy [action] [what] [where]` is the stable novice-facing architecture;
- `piggy stye` — visual pigsty map of where folder space is going;
- `piggy sniff imgs|vids|docs` — read-only largest media/docs in selected folders;
- richer image/video metadata when privacy-safe and dependency-light;
- cross-platform core exploration for files/folders/media, with per-platform app inventory modules.

## Codex for OSS fit

Piggy is being prepared as an open-source maintainer workflow project: small native codebase, clear tests, safety-critical filesystem behavior, and good candidates for Codex-assisted triage, JSON-based review, release checks, and security hardening.

See [`docs/codex-for-oss-readiness.md`](docs/codex-for-oss-readiness.md).

## License

Piggy is released under the [MIT License](LICENSE).
