# Contributing to Piggy

Piggy is a native Swift macOS CLI. Contributions should preserve its core promise: useful disk insight without reckless cleanup. Scan commands may cache metadata, but they should not delete or mutate user files.

## Development setup

```bash
swift test
swift build -c release
```

## Quality bar

Before opening a pull request:

1. Add or update tests for behavior changes.
2. Run `swift test`.
3. Run `swift build -c release`.
4. Smoke-test safe read-only commands, for example:

   ```bash
   swift run piggy mac audit
   swift run piggy mac list --sort size
   ```

## Safety rules

- Do not add destructive behavior without tests and explicit confirmation UX.
- Do not delete system apps or protected locations.
- Do not hide skipped files; report them.
- Do not add telemetry.
- Do not scan personal/private folders by default unless the command clearly says so and the user opts in.

## Pull request shape

Good PRs are small and explain:

- what changed;
- why it matters;
- how it was tested;
- any safety/privacy implications.
