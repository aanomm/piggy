# Codex for Open Source readiness

OpenAI’s Codex for Open Source program says open-source maintainers can apply for:

- six months of ChatGPT Pro with Codex;
- conditional Codex Security access for repositories that need deeper security coverage;
- API credits through the Codex Open Source Fund for projects using Codex in pull request review, maintainer automation, release workflows, or other core OSS work.

The page says core maintainers or maintainers of widely used public projects should apply, and that projects outside the strict criteria can still apply if they play an important ecosystem role and explain why.

Source reviewed: <https://developers.openai.com/community/codex-for-oss>

## Piggy’s current fit

Strengths:

- Native Swift CLI with a small, understandable codebase.
- Real test suite around scanner, size, safety, cache, audit, and removal-planning logic.
- Clear safety angle: local filesystem cleanup, protected locations, background agents, quarantine, and destructive-action risk.
- Obvious Codex use cases: PR review, test generation, release checklists, issue triage, security review, and docs automation.

Current weaknesses before applying:

- Repository needs to be public.
- Maintainer must choose an open-source license.
- No release artifacts or Homebrew install path yet.
- No public usage/adoption signal yet.
- CI should run on every pull request.
- Issue templates and security reporting should be completed after the GitHub repo exists.

## Recommended application positioning

Piggy should be framed as a safety-first macOS maintenance tool, not a generic cleaner.

Suggested angle:

> Piggy helps macOS users and maintainers audit app bloat, stale architectures, quarantine status, launch agents, and cleanup candidates with conservative safety checks. We use Codex to maintain filesystem-safety tests, review cleanup changes, harden path handling, and automate release/triage workflows for an open-source Swift CLI.

## Workflows worth mentioning

- Codex-assisted pull request review for filesystem safety and path handling.
- Codex-generated regression tests for each new scanner/removal rule.
- Codex Security review for destructive flows, symlink handling, and privacy-sensitive media scanning.
- Release automation that checks `swift test`, release builds, smoke commands, and docs.

## Pre-application checklist

- [ ] Public GitHub repository.
- [ ] Open-source license chosen and committed.
- [ ] README explains install, safety model, examples, and roadmap.
- [ ] CI workflow green on default branch.
- [ ] `SECURITY.md` has real private reporting path or GitHub private vulnerability reporting enabled.
- [ ] Contribution guide explains tests and safety rules.
- [ ] At least one tagged release or clear install command.
- [ ] Application narrative explains why Piggy is an OSS maintenance/security project worthy of Codex support.
