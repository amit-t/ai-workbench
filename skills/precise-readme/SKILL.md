---
name: precise-readme
description: Precision-mode pass on the project README + GH Pages docs corpus. Reads every .md in the project root + docs/, grills the user on scope / audience / aggression / dedup rule via /grill-me, rewrites each target file under precision-mode rules (lead with the answer, no filler, structure > prose), archives the originals under docs/v1/ with cross-banners so engineers who prefer the long-form keep a permanent home, and verifies the result with scripts/check-docs-links.sh and an em-dash sweep. Designed for the recurring "the README is too dense" complaint without losing the dense version for the engineers who liked it.
category: Cross-Cutting
relevant_topics: []
---

# /precise-readme

## When to use

- User reports the README or GH Pages docs are too dense for newcomers.
- After a feature wave: catalogue + tables grew, narrative around them did too.
- Periodic doc hygiene: kill drift between README long-form and `docs/<page>.md` long-form.
- Onboarding feedback says first-page comprehension is poor.

Not for: typo fixes, single-section rewrites, doc additions. Use a normal edit for those.

## Prerequisites

- Project has `README.md` at repo root and a `docs/` directory with one or more `*.md` pages.
- `scripts/check-docs-links.sh` exists (the audit guard). If missing, the skill still runs but skips the audit step and flags it.
- `bash`, `python3`, `git` available.

## Steps

0. **Load steering.** Layer 0 already loaded at session start. No Layer 2 ruleset applies (the skill is read-mostly-then-write, no typed artifact, no `target_repos:`).

1. **Scope the pass.** Enumerate every `.md` candidate:

   ```bash
   ls README.md
   ls docs/*.md
   wc -lw README.md docs/*.md
   ```

   Record baseline word + line counts per file; you will report deltas at the end.

2. **Grill the user.** Invoke `/grill-me quick` (5 hard-hitters; default is `deep` but `quick` is right for this skill). Resolve, in order:

   1. **Scope:** README + all `docs/*.md`? README only? README + user-facing pages only?
   2. **Audience:** new user landing cold? Existing collaborator who needs reference? Evaluator reading top-to-bottom?
   3. **Sacred:** confirm the always-preserve list (default below).
   4. **Aggression:** aggressive rewrite (40 to 50% reduction target, headings movable), trim in place (20 to 25%, structure unchanged), or surgical (worst offenders only).
   5. **Dedup rule:** README = pointer + `docs/` = source of truth (default), keep both, or move freely.

   Recommend `aggressive rewrite` + `README = pointer` as defaults: the duplicates between README and `docs/lifecycle.md` / `docs/ralph.md` / `docs/steering/` are usually where the bloat hides.

3. **Sacred-content rules (default; override only on explicit user instruction).**

   Preserve verbatim across the whole pass:
   - Every fenced code block (```...```).
   - Every markdown table (especially command tables, alias tables, configuration tables).
   - Every URL (full and Liquid-resolved both).
   - Every mermaid diagram.
   - Every per-skill catalogue row (skill name, hat, purpose).

   Permitted edits:
   - Prose paragraphs between sacred blocks.
   - Heading text (renames allowed if the dedup rule moves content).
   - Section ordering (within reason; keep H1 stable).
   - Bullet wording.

4. **Apply the precision-mode rules.** From `skills/precision-mode/` (if present) or the standard Layer 0 voice:

   - Lead with the answer; no preamble.
   - No filler phrases ("This page covers...", "It is worth noting that", "In order to").
   - No hype words: `leverage`, `utilize`, `robust`, `streamline`, `unlock`.
   - **No em-dashes (U+2014) outside code blocks.** Use commas, colons, or parentheses. Code blocks (fenced and inline) are exempt and preserve exact content.
   - Prefer tables / bullets / code blocks over prose when they compress information.
   - Cut trailing summaries.

5. **Apply the dedup rule.** When the chosen rule is `README = pointer`:

   - Find sections in README that fully duplicate a `docs/<page>.md` (lifecycle, ralph, steering, versioning, etc.).
   - Replace the long-form README section with a one-paragraph pointer + link.
   - The deep narrative stays in the `docs/` page (precision-passed there).

6. **Archive the originals under `docs/v1/`.** Engineers who prefer the dense version keep a permanent home.

   For each file in scope:
   - Mirror to `docs/v1/<basename>` (preserve frontmatter; rename `title:` to `<Title> (V1)`).
   - Prepend a blockquote banner immediately after the frontmatter:

     ```markdown
     > **V1 long-form archive.** Pre-precision-pass version, preserved for engineers who prefer the dense narrative.
     > New (V2) version: [<relative link to V2>](<link>).
     ```

   - For the repo-root `README.md`, mirror as `docs/v1/readme.md` with a frontmatter shim so Jekyll renders it under GH Pages at `/v1/readme.html`.

7. **Add V1 backlink to each V2 page.** Immediately after frontmatter:

   ```markdown
   *Prefer the old long-form? See [V1 archive](./v1/<basename>.html).*
   ```

   And in `README.md` + `docs/index.md`, add a prominent V1 entry-point link near the top so engineers can find the archive without hunting.

8. **Run pre-push verification.** Three checks in order:

   ```bash
   # Audit: forbids hardcoded owner URLs in docs/ (must pass).
   bash scripts/check-docs-links.sh

   # Em-dash sweep outside code blocks (must be 0):
   python3 -c "
   import re
   files = ['README.md'] + __import__('glob').glob('docs/**/*.md', recursive=True)
   hits = 0
   for f in files:
       with open(f) as fh: text = fh.read()
       stripped = re.sub(r'\`\`\`.*?\`\`\`', '', text, flags=re.DOTALL)
       for i, line in enumerate(stripped.split('\n'), 1):
           if '—' in line:
               print(f'{f}:{i}: {line.strip()[:100]}')
               hits += 1
   print(f'em-dash hits: {hits}')
   "

   # Internal link resolution — every relative ./foo.html or foo.md target must exist.
   python3 -c "
   import re, os
   import glob
   files = ['README.md'] + glob.glob('docs/**/*.md', recursive=True)
   broken = []
   for f in files:
       with open(f) as fh: text = fh.read()
       for m in re.finditer(r'\[([^\]]+)\]\(([^)]+)\)', text):
           target = m.group(2)
           if target.startswith(('http','mailto:','#','{{')) or target.startswith('skills/'):
               continue
           clean = target.split('#')[0].lstrip('./')
           if not clean: continue
           candidates = [clean, 'docs/' + clean.replace('.html','.md'), clean.replace('.html','.md'), os.path.join(os.path.dirname(f), clean)]
           if not any(os.path.exists(p) for p in candidates):
               broken.append(f'{f}: {target}')
   print('\\n'.join(broken) if broken else 'All internal links OK.')
   "
   ```

   If `audit` fails, the most common cause is hardcoded owner URLs in `docs/v1/readme.md` (the repo-root README is outside audit scope; once mirrored under `docs/v1/`, it gets scanned). Fix: replace literal `github.com/<owner>/...` and `<owner>.github.io/...` with Liquid lookups (`{{ links.ai_workbench_repo }}`, `{{ links.ai_workbench_pages }}`, etc.) and add `{% include links.html %}` after frontmatter.

   If em-dash hits > 0, replace with comma, colon, or parens. Inside code blocks: leave alone.

9. **Report the delta.** Print word + line counts before / after, per file and total:

   | File | Words (old → new) | Δ |
   |------|-------------------|---|
   | README.md | 2892 → 956 | -67% |
   | docs/... | ... | ... |
   | **Total** | 7592 → 4938 | **-35%** |

   Pages with small deltas are usually bound by sacred content (tables, code blocks, mermaid). Real prose density gain is higher than the headline number; surface that in the report so the user does not misread the metric.

10. **Hand off to the user.** Do not commit unless asked. Do not push. Do not open PRs. The skill's contract is "make the diff"; merging is the human's call.

## Default presets

If the user wants you to skip the grill, use these:

- **Scope:** README + all `docs/*.md`.
- **Audience:** new user landing cold.
- **Sacred:** code blocks + tables + URLs + mermaid (always).
- **Aggression:** aggressive rewrite, ~40 to 50% word reduction target, headings movable.
- **Dedup rule:** README = pointer, `docs/` = source of truth.

State the preset choices to the user before executing so they can intervene.

## Output contract

- Modifies: `README.md`, every `docs/*.md` in scope, `docs/v1/*` (mirror), optionally `docs/index.md` + `README.md` to add V1 entry-point links.
- No git operations. No remote operations. No PR creation. Caller drives those.
- Honors em-dash rule, no-hype-words rule, sacred-preserve rule by default.
- Surfaces per-file + total word + line delta on completion.

## Do not

- Do not rewrite content inside fenced code blocks. They are sacred.
- Do not paraphrase command tables. Rows are sacred; only the table's surrounding prose is fair game.
- Do not delete sections that have downstream readers (cross-repo links, blog posts, etc.) without confirming with the user.
- Do not skip the V1 archive. The complaint that drove this skill is "too dense", not "the dense version was wrong". Both must remain accessible.
- Do not introduce em-dashes outside code blocks. Project rule.
- Do not introduce hype words (`leverage`, `utilize`, `robust`, `streamline`, `unlock`).
- Do not exceed the agreed aggression band. Aggressive rewrite means rewrite; trim-in-place means trim. Match what the user asked for.
- Do not commit, push, or PR without explicit user instruction.
