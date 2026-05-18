---
title: /precise-readme
layout: default
eyebrow: Cross-Cutting
subtitle: "Precision-mode pass on the README + GH Pages docs corpus. Cuts filler, dedups README ↔ docs/ overlap, archives originals under `docs/v1/` with cross-banners. The fix for the recurring 'the README is too dense' complaint."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output |
|-----|-------|---------------|--------|
| Cross-cutting | Docs maintenance | None | In-place edits to `README.md` + `docs/*.md` + `docs/v1/*` mirror |

## When to use

- User reports the README or GH Pages docs are too dense for newcomers.
- After a feature wave: catalogue + tables grew, narrative around them did too.
- Periodic doc hygiene: kill drift between README long-form and `docs/<page>.md` long-form.
- Onboarding feedback says first-page comprehension is poor.

Not for: typo fixes, single-section rewrites, doc additions. Use a normal edit.

## Prerequisites

- `README.md` at repo root.
- `docs/` directory with one or more `*.md`.
- `scripts/check-docs-links.sh` (audit guard). If missing, skill runs and flags the gap.
- `bash`, `python3`, `git`.

## Run

```zsh
/precise-readme
```

## What it does

1. **Scope:** enumerates `README.md` + every `docs/*.md`, records baseline word + line counts.
2. **Grill:** invokes `/grill-me quick` for scope, audience, sacred bits, aggression, dedup rule. Defaults are sensible; you can pre-accept them.
3. **Rewrite:** applies precision-mode rules. Lead with the answer, no filler, structure > prose, no em-dashes outside code blocks, no hype words.
4. **Sacred preservation:** every fenced code block, every command/alias table, every URL, every mermaid diagram, every per-skill catalogue row is preserved verbatim.
5. **Dedup:** when `README = pointer` is chosen (default), long-form duplicates between README and `docs/<page>.md` collapse into one-paragraph pointers; `docs/` stays the source of truth.
6. **V1 archive:** mirrors every in-scope file to `docs/v1/<basename>` with a banner pointing forward to the V2 counterpart. Every V2 page gets a one-line backlink to V1. Engineers who liked the dense version keep a permanent home.
7. **Verify:** runs `scripts/check-docs-links.sh`, em-dash sweep outside code blocks, internal link resolution check.
8. **Report:** prints per-file + total word + line delta. Hands off to the user; does not commit or push.

## Default presets

If you want to skip the grill:

- **Scope:** README + all `docs/*.md`.
- **Audience:** new user landing cold.
- **Sacred:** code blocks + tables + URLs + mermaid (always).
- **Aggression:** aggressive rewrite, 40 to 50% word reduction target, headings movable.
- **Dedup rule:** README = pointer, `docs/` = source of truth.

## Output contract

- Modifies the doc corpus in place.
- No git operations. No remote operations. No PRs.
- Honors em-dash rule, no-hype-words rule, sacred-preserve rule by default.
- Reports word + line deltas per file and total.

## Reference run

Skill was distilled from a session that ran the pass on `amit-t/ai-workbench`:

| File | Words (old → new) | Δ |
|------|-------------------|---|
| README.md | 2892 → 956 | -67% |
| docs/architecture.md | 1091 → 961 | -12% |
| docs/faq.md | 557 → 403 | -28% |
| docs/getting-started.md | 270 → 215 | -20% |
| docs/index.md | 261 → 249 | -5% |
| docs/lifecycle.md | 434 → 391 | -10% |
| docs/onboarding-wsl.md | 264 → 228 | -14% |
| docs/ralph.md | 685 → 552 | -19% |
| docs/skills.md | 568 → 553 | -3% |
| docs/versioning.md | 570 → 430 | -25% |
| **Total** | **7592 → 4938** | **-35%** |

Pages with small deltas (skills, architecture) are dominated by sacred content (tables, code blocks). Real prose density gain is higher than the headline number.

## Do not

- Do not rewrite content inside fenced code blocks.
- Do not paraphrase command tables.
- Do not delete sections with external readers (cross-repo links, blog posts) without confirming.
- Do not skip the V1 archive. The complaint is "too dense", not "wrong"; both versions must remain accessible.
- Do not introduce em-dashes outside code blocks.
- Do not introduce hype words (`leverage`, `utilize`, `robust`, `streamline`, `unlock`).
- Do not commit, push, or PR without explicit user instruction.

## See also

{% include links.html %}

- [Skill source]({{ links.ai_workbench_repo }}/blob/main/skills/precise-readme/SKILL.md)
- [/grill-me](./grill-me.html): the interview engine `/precise-readme` invokes.
- [Skills reference](../skills.html): every skill, every input gate.
