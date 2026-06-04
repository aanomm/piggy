# Performance notes

Piggy should feel like a native macOS tool: fast startup, no hidden network calls, no shelling out in hot loops, and no repeated recursive scans when one traversal can produce the same result.

## Baseline fixture

The current local benchmark fixture creates 20 top-level folders, 10 nested folders per top-level folder, and 30 small files per nested folder, plus 10 files per top-level folder.

```bash
swift build -c release
python3 - <<'PY'
from pathlib import Path
root = Path('/tmp/piggy-perf-fixture')
root.mkdir(parents=True, exist_ok=True)
payload = b'piggy-perf' * 64
for i in range(20):
    top = root / f'Top-{i:02d}'
    top.mkdir(exist_ok=True)
    for f in range(10):
        (top / f'top-{f:02d}.bin').write_bytes(payload)
    for j in range(10):
        child = top / f'Child-{j:02d}'
        child.mkdir(exist_ok=True)
        for f in range(30):
            (child / f'file-{f:02d}.bin').write_bytes(payload)
PY
```

## Measured commands

```bash
/usr/bin/time -p .build/release/piggy folders /tmp/piggy-perf-fixture --depth 1 --limit 5 --min-size 1b
/usr/bin/time -p .build/release/piggy folders /tmp/piggy-perf-fixture --depth 2 --limit 5 --min-size 1b
/usr/bin/time -p /usr/bin/du -sk /tmp/piggy-perf-fixture/*
```

Before the single-pass folder traversal change, representative times were:

| Command | Real time |
| --- | ---: |
| `piggy folders --depth 1` | 0.08s |
| `piggy folders --depth 2` | 0.14s |
| `du -sk` immediate children | 0.01s |

After the single-pass traversal change, representative repeated-run measurements were:

| Command | Min | Median | Max |
| --- | ---: | ---: | ---: |
| `piggy folders --depth 1` | 0.2232s | 0.3330s | 0.6944s |
| `piggy folders --depth 2` | 0.1585s | 0.2035s | 2.0462s |
| `du -sk` fixture root | 0.0488s | 0.0519s | 0.0585s |

The important correctness/performance change is architectural: nested folder findings are now produced from a single recursive walk instead of collecting candidate folders and recursively re-counting each candidate. This matters more as `--depth` increases.

## Next optimization targets

- Add a checked-in benchmark script with stable fixture creation and JSON/CSV output.
- Consider bounded parallel traversal for large top-level folders.
- Avoid expensive code-signing or architecture inspection unless a command needs it.
- Keep `PiggyKit` scanners pure enough to benchmark without terminal rendering.
- Add `--json` output for machine-readable timing and automation.
