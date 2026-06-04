# Piggy media scanning roadmap

Short answer: yes, Piggy can grow into `piggy folders`, `piggy media`, `piggy images`, and `piggy video`, but it should not start by crawling every personal folder on the Mac.

## Recommended command design

```bash
piggy folders ~/Downloads --limit 25
piggy folders ~/Library --min-size 1gb
piggy media --path ~/Downloads --limit 25
piggy images --path ~/Pictures --limit 25
piggy video --path ~/Movies --limit 25
```

Safe defaults:

- non-destructive; cache writes are okay, file deletion is not;
- scan only explicit paths or a small low-surprise default like `~/Downloads`;
- do not enter Photos Library, iCloud Drive, external drives, or hidden folders unless opted in;
- cache metadata separately from app-scan cache;
- show what was skipped.

## Technical approach

Folders:

- Use Foundation/FileManager for traversal.
- Rank child directories by recursive visible contents, not by inode metadata.
- Report file count and nested folder count beside each folder.
- Keep `--depth 1` as the default to avoid noisy/double-counted nested rows.

Images:

- Use Foundation/FileManager for traversal.
- Use UniformTypeIdentifiers to identify image files.
- Use ImageIO (`CGImageSource`) for width/height when available.
- Rank by file size first, then optionally dimensions.

Videos/audio:

- Use UniformTypeIdentifiers for media type detection.
- Use AVFoundation for duration/resolution when available.
- Fall back to file size/type when metadata cannot be read.

Media summary:

- Total scanned files and total bytes.
- Largest files by type.
- Duplicate-looking candidates later via size/hash, but hashing should be opt-in because it reads whole files.

## Why not fine-tuning first?

No model fine-tuning is needed for v1. Piggy’s first media features are deterministic filesystem and metadata work. AI can help later with:

- natural-language explanations;
- file grouping suggestions;
- image/video semantic labels;
- duplicate-cluster descriptions.

But semantic analysis would be privacy-sensitive and should be opt-in, local-first if possible, and clearly separate from the default read-only scanner.

## Proposed implementation order

1. Keep improving `piggy folders` with skip reporting and optional exports.
2. Add `PiggyKit/Media` types: `MediaKind`, `MediaItem`, `MediaScanSummary`.
3. Add tests for extension/UTType classification and ranking.
4. Add `piggy media --path <dir>` non-destructive scanner.
5. Add aliases/subcommands `piggy images` and `piggy video` as filtered views.
6. Add metadata enrichment with ImageIO/AVFoundation.
7. Add cache and skip reporting.
