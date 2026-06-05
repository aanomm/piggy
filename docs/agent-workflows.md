# Agent workflows

Piggy is designed to be useful to humans in a terminal and to coding agents that need stable, reviewable Mac inventory data.

The human output is intentionally compact. Agents should prefer JSON output so they do not scrape tables.

## Safe read-only commands

These commands do not delete, move, or edit user files. They may update Piggy's local scan cache.

```bash
piggy mac audit
piggy mac list --json
piggy mac list --rosetta --json
piggy mac search xcode --json
piggy mac info Xcode --json
piggy folders ~/Downloads --limit 25
piggy export --format json
```

## JSON app schema

`piggy mac list --json` and `piggy mac search <query> --json` return an array of app records. `piggy mac info <app> --json` returns one record.

Important fields:

- `name` — display name from the app bundle.
- `bundle_id` — bundle identifier when available.
- `path` — app bundle path.
- `size_bytes` / `size_formatted` — on-disk app bundle size.
- `architecture` / `architecture_label` — chip architecture classification.
- `installed_by` — `Apple`, `App Store`, or `Direct`.
- `scope` — `System`, `System-wide`, or `User`.
- `flagged` — compact reasons the app may deserve review, such as `Rosetta`, `Incompatible`, or `Downloaded`.
- `helpers` — count of launch/background helper files associated with the app when Piggy can detect them.

Example:

```bash
piggy mac list --rosetta --json > rosetta-apps.json
```

```json
[
  {
    "architecture": "x86_64",
    "architecture_label": "x86_64 (Intel/Rosetta)",
    "flagged": ["Rosetta"],
    "installed_by": "Direct",
    "name": "Example",
    "path": "/Applications/Example.app",
    "size_bytes": 1048576,
    "size_formatted": "1.0 MB"
  }
]
```

## Suggested Codex usage

Use Codex or another coding agent for work that benefits from repeatable review:

1. Run safe inventory commands and attach JSON outputs to an issue or PR.
2. Ask for analysis of patterns, not automatic deletion decisions.
3. For code changes, require tests around scanner behavior, path handling, symlink behavior, cache behavior, and destructive flows.
4. Before merge, run:

   ```bash
   swift test
   swift build -c release
   NO_COLOR=1 .build/release/piggy mac audit
   NO_COLOR=1 .build/release/piggy mac list --json
   ```

## Safety boundaries for agents

Agents should not run destructive Piggy commands unless a human explicitly asks for that exact action in the current task.

Destructive or potentially destructive commands include:

```bash
piggy delete <app>
piggy delete <app> --with-related
```

When proposing cleanup, agents should report:

- what Piggy observed;
- why an app deserves review;
- what command would be needed if the human chooses to act;
- what Piggy will refuse or skip for safety.

Do not treat Piggy output as permission to delete. Piggy is a review tool first. Tiny pig, big seatbelt.
