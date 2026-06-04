# Piggy

Piggy is a native macOS command-line tool for finding application bloat, stale binaries, background agents, and safe cleanup candidates without pretending deletion is simple.

It is intentionally non-destructive by default. Scan commands may update Piggy’s local cache, but they do not delete apps or support files. Destructive actions are explicit, confirmation-gated, and backed by safety checks.

```bash
piggy mac audit
piggy folders ~/Downloads --limit 25
piggy mac list --sort size
piggy mac list --rosetta
piggy mac orphans
```

## Why Piggy exists

macOS app cleanup is weird: an app bundle can be huge, Intel-only, quarantined, Apple-signed, App Store managed, or surrounded by launch agents and leftover support files. Most cleaners flatten those differences into a scary “delete this” button.

Piggy’s job is calmer:

- show what is actually taking space;
- explain why something deserves review;
- keep Apple/system apps protected;
- surface background agents and leftovers;
- make cleanup auditable instead of vibes-based.

## Current features

- Non-destructive Mac audit summary: `piggy mac audit`
- Folder size audit with recursive file counts: `piggy folders ~/Downloads`
- App scanner for `/Applications`, `/System/Applications`, and `~/Applications`
- Size, architecture, origin, quarantine, and background-agent detection
- Largest-app ranking and advanced list filters
- Orphan/leftover discovery for deleted apps
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

## Install from source

Requirements:

- macOS 14+
- Swift 6 toolchain / Xcode command line tools

```bash
git clone <repo-url> piggy
cd piggy
swift build -c release
install -m 755 .build/release/piggy /usr/local/bin/piggy
```

For local development without installing globally:

```bash
swift run piggy mac audit
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
- [`docs/codex-for-oss-readiness.md`](docs/codex-for-oss-readiness.md) — Codex for Open Source submission notes.

## Accessibility and terminal output

Piggy treats terminal output as UI:

- color is disabled automatically when stdout is not a TTY;
- `NO_COLOR=1` disables ANSI color;
- `PIGGY_COLOR=always` or `PIGGY_COLOR=never` can override color behavior;
- scan animation is skipped for non-interactive output so logs stay clean.

## Safety model

Piggy treats cleanup as a safety problem, not just a filesystem operation.

- `piggy mac audit`, `list`, `info`, `search`, `orphans`, and `export` are non-destructive; scans may refresh Piggy’s local cache.
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

- `piggy folders` — biggest directories in selected paths with recursive file/folder counts;
- `piggy media` — read-only largest images/videos/audio in selected folders;
- `piggy images` — largest image files with dimensions and type;
- `piggy video` — largest videos with duration/resolution when metadata is available;
- explicit `--path` / `--include` options before scanning personal libraries.

## Codex for OSS fit

Piggy is being prepared as an open-source maintainer workflow project: small native codebase, clear tests, safety-critical filesystem behavior, and good candidates for Codex-assisted triage, review, release checks, and security hardening.

See [`docs/codex-for-oss-readiness.md`](docs/codex-for-oss-readiness.md).

## License

Piggy is released under the [MIT License](LICENSE).
