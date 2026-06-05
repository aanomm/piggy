# Piggy Foundation + Piggy Web Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Turn Piggy from a promising Mac app scanner into an exceptional modular CLI for finding bloat, waste, risk, and obvious wins across Mac and web surfaces.

**Architecture:** Keep Swift as the implementation language for now because Piggy is already a Swift Package, builds successfully on sayso's Mac, has one dependency, and is naturally suited to macOS filesystem/AppKit operations. Refactor into a modular package with `Core`, `Mac`, `Web`, `Reporting`, and `CLI` areas while preserving current functionality behind compatibility aliases.

**Tech Stack:** Swift Package Manager, Swift ArgumentParser, Foundation URLSession, XCTest, optional future browser/Lighthouse adapters only after the static web scanner is excellent.

---

## Current State Snapshot

Path: `/Users/sayso/local/apps/piggy`

- Stack: Swift Package, macOS 14+, Swift 6.0 tools, Swift ArgumentParser.
- Source size: ~3,016 Swift LOC.
- Build: `swift build -c release` passes.
- Tests: no `Tests/` target exists; `swift test` reports `error: no tests found`.
- Install: `/usr/local/bin/piggy` points to `/Users/sayso/local/apps/piggy/.build/release/piggy`.
- Git: no `.git` repo detected in the project directory.

Current commands:

- `piggy snort`
- `piggy list`
- `piggy info`
- `piggy delete`
- `piggy search`
- standalone orphan scan (historical; later removed from the public surface pending a sharper safety story)
- `piggy export`

Major issues to fix before Piggy Web:

1. No tests.
2. No source control detected.
3. Monolithic CLI file (`CleanyCommands.swift`, 508 LOC).
4. Monolithic TUI file (`AppTUI.swift`, 863 LOC).
5. Destructive operations exist before a formal safety model.
6. Quarantine detection appears incorrect: uses `.immutable` instead of extended attribute `com.apple.quarantine`.
7. `AppScanner.getLastUsedDate` calls `mdls` with a query string shaped incorrectly for normal `mdls` path usage; likely unreliable.
8. Orphan detection is heuristic and could flag sensitive Library paths; needs confidence levels and dry-run-first reporting.
9. Related-file deletion lacks per-file error reporting.
10. Output formatting, byte formatting, relative dates, and reports are duplicated instead of centralized.

---

## Product North Star

Piggy is not a random utility. Piggy is:

> A tiny expert that finds bloat, waste, risk, and obvious wins — then explains what matters and what to do safely.

Every scan must produce:

1. Evidence.
2. Plain-English meaning.
3. Priority.
4. Safe next action.
5. Machine-readable JSON where useful.

---

## Desired CLI Shape

Keep existing aliases working, but introduce the future structure:

```bash
piggy mac scan
piggy mac apps
piggy mac app-info "Arc"
piggy mac export --format json

piggy web scan https://example.com
piggy web crawl https://example.com --limit 25

piggy doctor
```

Compatibility aliases:

```bash
piggy snort      -> piggy mac apps --sort size
piggy list       -> piggy mac apps
piggy info       -> piggy mac app-info
piggy export     -> piggy mac export
```

Deletion should become visibly safety-framed:

```bash
piggy mac trash-app "App Name" --include-related
```

Avoid the casual word `delete` for UX. Keep `delete` as deprecated alias temporarily.

---

## Target Source Layout

```text
Sources/piggy/
├─ main.swift
├─ CLI/
│  ├─ PiggyCommand.swift
│  ├─ MacCommands.swift
│  ├─ WebCommands.swift
│  └─ DoctorCommand.swift
├─ Core/
│  ├─ ByteFormat.swift
│  ├─ DateFormat.swift
│  ├─ Finding.swift
│  ├─ FindingSeverity.swift
│  ├─ FindingPriority.swift
│  ├─ Score.swift
│  ├─ Safety.swift
│  └─ TerminalOutput.swift
├─ Mac/
│  ├─ Models/AppInfo.swift
│  ├─ Scanner/AppScanner.swift
│  ├─ Scanner/AppScanCache.swift
│  ├─ Scanner/AgentScanner.swift
│  ├─ Scanner/CodeSignChecker.swift
│  ├─ Scanner/QuarantineChecker.swift
│  ├─ Scanner/SizeCalculator.swift
│  ├─ Remover/AppTrashService.swift
│  └─ Remover/OrphanScanner.swift
├─ Web/
│  ├─ WebScanCommand.swift
│  ├─ WebScanner.swift
│  ├─ HTTPProbe.swift
│  ├─ HTMLAnalyzer.swift
│  ├─ SecurityHeaderAnalyzer.swift
│  ├─ SEOAnalyzer.swift
│  ├─ AssetAnalyzer.swift
│  ├─ WebFinding.swift
│  └─ WebReport.swift
├─ Reporting/
│  ├─ MarkdownReport.swift
│  ├─ JSONReport.swift
│  └─ ClientReport.swift
├─ TUI/
└─ UI/
```

Tests:

```text
Tests/piggyTests/
├─ Core/
├─ Mac/
└─ Web/
```

---

# Phase 0: Project Safety and Source Control

## Task 0.1: Create git repository if still absent

**Objective:** Protect current work before refactoring.

**Files:** none initially.

**Steps:**

1. Run:

```bash
cd /Users/sayso/local/apps/piggy
git status
```

2. If not a git repo, initialize:

```bash
git init
git add Package.swift Sources
git commit -m "chore: checkpoint current piggy source"
```

3. Verify:

```bash
git status --short
```

Expected: clean or only ignored build artifacts.

## Task 0.2: Add `.gitignore`

**Objective:** Prevent `.build` and macOS junk from entering source control.

**Files:**
- Create: `.gitignore`

**Content:**

```gitignore
.build/
.swiftpm/
.DS_Store
*.xcodeproj/
xcuserdata/
DerivedData/
```

**Verify:**

```bash
git status --short
```

Expected: `.build/` not listed.

---

# Phase 1: Test Harness

## Task 1.1: Add XCTest target

**Objective:** Make `swift test` real.

**Files:**
- Modify: `Package.swift`
- Create: `Tests/piggyTests/Core/ByteFormatTests.swift`

**Package change:** add test target:

```swift
.testTarget(
    name: "piggyTests",
    dependencies: ["piggy"]
)
```

If executable internals cannot be imported cleanly, split a library target:

```swift
.target(
    name: "PiggyKit",
    dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")],
    resources: [.process("Data/purpose.json")]
),
.executableTarget(
    name: "piggy",
    dependencies: ["PiggyKit"]
),
.testTarget(
    name: "PiggyKitTests",
    dependencies: ["PiggyKit"]
)
```

Preferred: create `PiggyKit` so modules are testable.

**Verify:**

```bash
swift test
```

Expected: at least one passing test.

## Task 1.2: Centralize byte formatting

**Objective:** Remove repeated byte formatting code.

**Files:**
- Create: `Sources/PiggyKit/Core/ByteFormat.swift`
- Create test: `Tests/PiggyKitTests/Core/ByteFormatTests.swift`

**Behavior:**

- `0` -> `0 B`
- `1536` -> `1.5 KB`
- `1_048_576` -> `1.0 MB`
- `1_073_741_824` -> `1.00 GB`

**Verify:**

```bash
swift test --filter ByteFormatTests
```

---

# Phase 2: Core Finding Model

## Task 2.1: Add finding severity and priority model

**Objective:** Give Piggy a shared language for Mac and Web issues.

**Files:**
- Create: `Sources/PiggyKit/Core/Finding.swift`
- Create: `Tests/PiggyKitTests/Core/FindingTests.swift`

**Model:**

```swift
public enum FindingSeverity: String, Codable {
    case info
    case low
    case medium
    case high
    case critical
}

public enum FindingEffort: String, Codable {
    case tiny
    case small
    case medium
    case large
    case unknown
}

public struct Finding: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let explanation: String
    public let evidence: [String]
    public let severity: FindingSeverity
    public let effort: FindingEffort
    public let confidence: Double
    public let reclaimableBytes: Int64?
}
```

**Priority rule:**

Implement deterministic ranking:

```text
severity weight × confidence ÷ effort weight
```

**Verify:** high severity + tiny effort ranks above medium severity + large effort.

---

# Phase 3: Mac Module Refactor

## Task 3.1: Move current app scanning into `Mac/`

**Objective:** Keep current behavior, but separate it from CLI glue.

**Files:**
- Move `Models/AppInfo.swift` -> `Mac/Models/AppInfo.swift`
- Move scanner files into `Mac/Scanner/`
- Move remover files into `Mac/Remover/`

**Verify:**

```bash
swift build -c release
piggy list --fresh
```

Expected: same behavior as before.

## Task 3.2: Replace quarantine detection

**Objective:** Correctly detect macOS quarantine xattr.

**Files:**
- Create: `Sources/PiggyKit/Mac/Scanner/QuarantineChecker.swift`
- Modify: `AppScanner.swift`
- Modify: `CodeSignChecker.swift` or remove incorrect method.

**Implementation approach:** use `getxattr` for `com.apple.quarantine`.

**Verify:** unit test using a temporary file with `setxattr` if feasible, otherwise isolate function and integration-test manually.

## Task 3.3: Add safety classification for removable items

**Objective:** Stop treating every related/orphan file equally.

**Files:**
- Create: `Sources/PiggyKit/Core/Safety.swift`
- Modify: `AppRemover.swift` -> `AppTrashService.swift`
- Modify: `OrphanScanner.swift`

**Safety levels:**

```swift
public enum SafetyLevel: String, Codable {
    case safeReview
    case cautious
    case sensitive
    case blocked
}
```

Rules:

- `/System/*` -> blocked
- iCloud/CloudStorage paths -> sensitive/blocked by default
- `~/Library/Containers` -> cautious
- `~/Library/Group Containers` -> cautious/sensitive
- app cache folders -> safeReview or cautious depending confidence

**Verify:** unit tests for path classification.

## Task 3.4: Improve trash behavior

**Objective:** Report per-file success/failure and never claim freed bytes before trash succeeds.

**Files:**
- Modify: `AppTrashService.swift`
- Add tests with mocked trash protocol if possible.

**Behavior:**

- calculate `estimatedBytes`
- report `trashedBytes` only for successful recycle callbacks
- collect errors
- show skipped blocked/sensitive items

---

# Phase 4: New CLI Structure

## Task 4.1: Add `piggy mac` namespace

**Objective:** Introduce modular CLI without breaking old commands.

**Files:**
- Modify: `main.swift`
- Create: `CLI/PiggyCommand.swift`
- Create: `CLI/MacCommands.swift`

**Commands:**

```swift
struct Mac: ParsableCommand { ... }
struct MacScan: ParsableCommand { ... }
struct MacApps: ParsableCommand { ... }
struct MacAppInfo: ParsableCommand { ... }
struct MacOrphans: ParsableCommand { ... }
```

**Compatibility:** old `List`, `Info`, `Snort`, etc. remain but delegate.

**Verify:**

```bash
piggy mac apps --fresh
piggy list --fresh
```

Both should work.

## Task 4.2: Add `piggy doctor`

**Objective:** Let Piggy explain its environment and install state.

**Checks:**

- Swift-built binary path
- cache location
- terminal capability
- app directories readable
- write permissions for report output

---

# Phase 5: Piggy Web Static MVP

## Task 5.1: Add `piggy web scan <url>` command

**Objective:** Create static website scan entry point without browser dependency.

**Files:**
- Create: `Sources/PiggyKit/Web/WebScan.swift`
- Create: `Sources/PiggyKit/Web/HTTPProbe.swift`
- Create: `CLI/WebCommands.swift`
- Create tests under `Tests/PiggyKitTests/Web/`

**Behavior:**

```bash
piggy web scan https://example.com
piggy web scan example.com --save ./audit
```

Normalize schemeless domains to `https://`.

## Task 5.2: HTTP probe

**Checks:**

- final URL
- status code
- redirect count
- elapsed time
- content type
- response body size
- response headers

**Safety:**

- block private/local IPs by default after DNS resolution
- allow via `--allow-private`
- timeout default 10s
- max body read default 5 MB for HTML

## Task 5.3: Security header analyzer

**Findings:**

- missing HSTS
- missing CSP
- missing frame protection
- missing referrer policy
- missing permissions policy
- insecure HTTP final URL

## Task 5.4: HTML analyzer

**Findings:**

- title missing/too short/too long
- meta description missing
- viewport missing
- canonical missing
- H1 missing/multiple
- missing `html lang`
- images missing alt
- obvious CTA missing
- Open Graph missing
- JSON-LD structured data absent/present

Use lightweight parsing first. Avoid pulling a large HTML parser unless regex/string scanning proves too fragile.

## Task 5.5: Asset analyzer

**Findings:**

- number of scripts/styles/images/fonts
- third-party domains
- oversized HTML
- obvious heavy assets by `Content-Length` if fetched with HEAD
- compression missing
- cache headers absent

Use concurrency with hard limits.

## Task 5.6: Web scoring and report

**Subscores:**

- Bloat/Performance
- Trust/Security
- SEO Basics
- Accessibility Basics
- Conversion Readiness

**Outputs:**

- terminal summary
- `piggy-web.md`
- `piggy-web.json`
- optional `piggy-web-client.md`

---

# Phase 6: Piggy Web Crawl MVP

## Task 6.1: Add `piggy web crawl <url> --limit 25`

**Objective:** Audit multiple internal pages safely.

**Rules:**

- same-origin only by default
- max pages default 10, hard default cap 25 unless user overrides
- robots behavior: report robots.txt but do not pretend to be Googlebot
- rate limit: 2 concurrent requests by default
- skip binary/media files

**Findings:**

- broken internal links
- duplicate titles
- missing descriptions
- redirect chains
- oversized pages
- weak CTA pages

---

# Phase 7: Optional Browser Mode Later

Only after static Piggy Web is excellent.

```bash
piggy web scan https://example.com --browser
```

Rules:

- use installed Chrome/Chromium only if user opts in
- no `--no-sandbox` by default
- temporary isolated browser profile
- capture console errors, page weight, screenshots, LCP-ish metrics
- Lighthouse adapter optional, not core

---

# Definition of Exceptional

Piggy is acceptable only when:

1. `swift test` passes.
2. `swift build -c release` passes.
3. Existing Piggy Mac behavior still works.
4. Destructive operations are safer than before.
5. New CLI shape is clear and modular.
6. Static web scan works without Node, npm, Rust, Chrome, or Python.
7. Reports are useful to both a developer and a client.
8. JSON output exists for automation.
9. No private/protected Mac locations are accessed beyond current explicit feature scope.
10. The terminal output is concise, cute, and genuinely useful.

---

# Immediate Next Step

Implement Phase 0 and Phase 1 first. Do not start Piggy Web until the package has source control, tests, centralized formatting, and a basic modular `PiggyKit` target.
