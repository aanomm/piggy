# Terminal design notes

Piggy’s terminal UI should feel warm and clear without becoming noisy. The goal is not novelty ASCII for its own sake; the goal is instant comprehension and trust.

## References reviewed

- Command Line Interface Guidelines — <https://clig.dev/>
- NO_COLOR informal standard — <https://no-color.org/>
- Charm terminal UI ecosystem — <https://charm.sh/>
- Pig ASCII-art references for visual motif inspiration — <https://ascii.co.uk/art/pig>

## Applied principles

- **Human-first output:** say what Piggy scanned, what disk metric means, and what safe next command to run.
- **Color is decoration, not meaning:** Piggy respects `NO_COLOR`, disables ANSI when stdout is not a TTY, and allows `PIGGY_COLOR=always|never` overrides.
- **Responsive banner:** the splash adapts to wide, medium, and narrow terminals.
- **Animation only when interactive:** scan animation is skipped for non-TTY output so logs and CI remain clean.
- **Avoid plagiarism:** ASCII-art references are used as motif inspiration only; Piggy’s banner is custom.

## Future UX directions

1. **Calm audit cards:** show summary metrics in grouped cards with clear section headings and no more than one accent color per section.
2. **Accessible table mode:** add `--plain` or `--no-style` for fixed ASCII separators, no box drawing, no emoji, and predictable screen-reader flow.
3. **Progress semantics:** show exact phase names during long scans, e.g. `scanning apps`, `checking signatures`, `ranking findings`, instead of only animation.
