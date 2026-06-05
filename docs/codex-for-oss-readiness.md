# Codex for Open Source readiness

OpenAI’s Codex for Open Source program says open-source maintainers can apply for:

- six months of ChatGPT Pro with Codex;
- conditional Codex Security access for repositories that need deeper security coverage;
- API credits through the Codex Open Source Fund for projects using Codex in pull request review, maintainer automation, release workflows, or other core OSS work.

The page says core maintainers or maintainers of widely used public projects should apply, and that projects outside the strict criteria can still apply if they play an important ecosystem role and explain why.

Source reviewed: <https://developers.openai.com/community/codex-for-oss>

## Piggy’s current fit

Strengths:

- Public Swift CLI prepared for open-source submission.
- MIT-licensed codebase with CI, README, contribution guide, security policy, and issue templates.
- Native Swift package with a small, understandable architecture.
- Real test suite around scanner, command grammar, size, safety, cache, audit, and removal-planning logic.
- Clear safety angle: local filesystem cleanup, protected locations, background agents, quarantine, symlink handling, and destructive-action risk.
- Compact human output plus JSON records for agent-assisted review without table scraping.
- Obvious Codex use cases: PR review, test generation, release checklists, issue triage, security review, and docs automation.

Current weaknesses to be transparent about:

- No tagged public release yet.
- No Homebrew install path yet.
- Adoption signal will start small because the repository is newly public.
- Codex Security access would be especially useful because Piggy handles local filesystem cleanup and path safety.

## Recommended application positioning

Piggy should be framed as a safety-first, novice-friendly local disk visibility tool — not a generic cleaner.

Suggested angle:

> Piggy helps everyday users see what is taking up space on their Mac with a simple `piggy [action] [what] [where]` command language, while giving maintainers auditable, conservative safety checks around app metadata, folder scans, privacy-sensitive media/docs scans, and destructive cleanup flows. We use Codex to maintain filesystem-safety tests, review cleanup changes, harden path handling, and automate release/triage workflows for an open-source Swift CLI.

## Workflows worth mentioning

- Codex-assisted pull request review for filesystem safety and path handling.
- Codex-generated regression tests for each new scanner/removal rule.
- Codex Security review for destructive flows, symlink handling, and privacy-sensitive media scanning.
- Agent-readable JSON inventory review via `piggy mac list --json`, `search --json`, and `info --json`.
- Release automation that checks `swift test`, release builds, smoke commands, and docs.

## Pre-application checklist

- [x] Public GitHub repository.
- [x] Open-source license chosen and committed.
- [x] README explains install, safety model, examples, and roadmap.
- [x] CI workflow exists for pull requests and default branch pushes.
- [x] `SECURITY.md` points to GitHub private vulnerability reporting.
- [x] Contribution guide explains tests and safety rules.
- [ ] First tagged release or Homebrew install path.
- [x] Application narrative explains why Piggy is an OSS maintenance/security project worthy of Codex support.

## Short submission blurb

Piggy is a safety-first, novice-friendly native macOS CLI for seeing what is taking up space — apps, folders, images, videos, and docs — through a simple `piggy [action] [what] [where]` command language. It is intentionally non-destructive by default, has tests around command grammar, filesystem safety, scans, and removal planning, and is a strong fit for Codex-assisted maintenance because every feature touches areas where review quality matters: path handling, symlink behavior, protected locations, privacy-sensitive scans, JSON output contracts, and destructive cleanup UX.

We plan to use Codex for pull request review, security hardening, regression-test generation, release checklists, and issue triage so Piggy can grow into a trustworthy open-source macOS maintenance tool rather than another opaque “cleaner.”
