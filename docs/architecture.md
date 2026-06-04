# Architecture

Piggy is split into a small CLI front end and a testable Swift library. The project goal is native-speed macOS disk insight with conservative cleanup safety.

## Package layout

```text
Sources/
  PiggyKit/
    Core/        Shared models, byte formatting/parsing, safety helpers, terminal style.
    Mac/         macOS-specific scanners, app metadata, caches, code-signing, removal plans.
  piggy/
    CLI/         ArgumentParser commands and terminal output formatting.
    Scanner/     CLI-facing app, agent, and orphan scanning flows.
    Remover/     Destructive flows guarded by removal plans and confirmation UX.
    TUI/         Interactive app browser.
    UI/          Splash banner, responsive menu, and scan animation.
    Data/        Small bundled lookup data.
Tests/
  PiggyKitTests/ Test coverage for scanner, audit, safety, cache, removal, and formatting logic.
```

## Command surface

```text
piggy
├── mac audit      read-only app/bloat summary
├── mac list       app inventory with filters and sort options
├── mac info       details for one app
├── mac orphans    leftover support-file discovery
├── mac delete     explicit, confirmation-gated cleanup
└── folders        read-only folder-size audit for an opt-in path
```

Top-level compatibility aliases (`audit`, `list`, `snort`, `orphans`, etc.) remain available while the namespaced `mac` commands become the primary public surface.

## Design principles

1. **Non-destructive by default.** Audit/list/search/export commands can read and cache metadata, but they do not delete user files.
2. **Filesystem safety beats cleverness.** Symlinks, system paths, Apple apps, cloud folders, containers, and ambiguous leftovers are treated conservatively.
3. **Explain the why.** Piggy should say what it found, what it means, and what a safe next command is.
4. **Opt-in privacy.** Piggy does not scan broad personal libraries by surprise. Commands that inspect user media or private directories should require explicit paths.
5. **Fast enough to feel native.** Scanner work should avoid duplicate traversals, shelling out in hot loops, hidden network calls, and expensive formatting in hot loops.
6. **Terminal output is UI.** Tables, color, animation, and copy should be readable in narrow terminals, non-color terminals, and pasted logs.

## Safety boundaries

Destructive behavior must pass three gates:

1. The target is classified and system/Apple-protected paths are blocked.
2. Related support files are planned and reported before removal.
3. The user confirms the operation unless they explicitly pass a force flag.

Additional safety rules:

- Folder scans do not follow symlinks into unexpected locations.
- Related-file deletion reports skipped/ambiguous files instead of silently ignoring them.
- No telemetry. No background network calls.
- Media/photo-library scans stay roadmap-only until they have explicit path scopes and privacy language.

## Performance model

- App scans cache parsed metadata in `AppScanCache` and refresh on `--fresh`.
- Folder scans use a single recursive pass: each directory contributes metrics upward while findings are emitted only for the requested depth.
- CLI commands keep domain work in `PiggyKit` so behavior remains testable and benchmarkable.

## Terminal UX

Piggy output should be useful in both pretty terminals and plain logs:

- respect `NO_COLOR`, `TERM=dumb`, non-TTY output, and `PIGGY_COLOR=always|never`;
- never rely on color alone for meaning;
- use compact, aligned tables for scan results;
- keep animations TTY-only and clear them before printing final results;
- keep a non-interactive fallback for `piggy` so scripts never hang waiting for a menu.

## Near-term roadmap

1. **Release path:** public repo, CI, signed/tagged release, Homebrew formula.
2. **Safer media audits:** `piggy images`, `piggy video`, and `piggy media` scoped to explicit directories.
3. **Performance:** larger fixture benchmarks, optional parallel folder traversal, cached app metadata invalidation tests.
4. **UX:** refined tables, `--json` output, quiet/no-color modes, richer screen-reader-friendly text fallbacks.
5. **Security:** private vulnerability reporting, Codex-assisted path/symlink review, destructive-flow fuzz/regression tests.
