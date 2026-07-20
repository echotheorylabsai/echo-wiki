# Keeping Content Fresh

Echo Wiki is **command-driven, not automatic**. The skills keep the source-to-KB pipeline consistent when you run them, but they do not watch files, continuously re-fetch URLs, or silently rewrite your notes and derived artifacts.

Use this page whenever a source, workspace note, or product area changes.

## What Changed? What Next?

| Change | Next action | What updates |
|---|---|---|
| New URL, PDF, or local file | `/ingest <url-or-path>` | A new raw receipt is written, then `/compile` runs for it. |
| Raw Markdown added manually | Validate it, then `/compile raw/<path>.md` | The source summary and affected KB articles are created or merged; indexes and backlinks regenerate. |
| Your workspace note or draft changed | `/index` | `_index.md` and `_backlinks.md` include the workspace change. |
| New KB evidence affects a developer context pack | `/context <product-area>` | That context pack is recreated or refreshed from current evidence. |
| You need a fresh answer to a prior question | `/query <question>` again | A new or matching durable answer is updated only when the query is worth filing. |
| You want a health/freshness scan | `/maintain` or `/lint all` | Reports, indexes, and the maintenance queue refresh; factual KB content is not rewritten. |
| A raw source was deliberately deleted | `/rebuild` | A staged KB replacement is rebuilt from the remaining raw sources. |

## The Normal Path: Add New Evidence

For a new source, use `/ingest`. It creates a clean Markdown receipt under `raw/`, validates it, and then runs `/compile`. Compilation creates a source summary, creates or merges configured KB article types, regenerates indexes and backlinks, and validates the written articles.

```text
New source → /ingest → raw/ receipt → /compile → KB articles + index + validation
```

If you deliberately add a raw Markdown receipt yourself, first run:

```bash
./hooks/validate.sh raw/<category>/<file>.md
```

Then run `/compile raw/<category>/<file>.md`. Do not hand-edit KB type directories; they are the compiled projection of `raw/`.

## What Does Not Refresh Itself

The KB projection updates during compilation, but the following are derived working artifacts—not live views:

| Artifact | Refresh it with | Important behavior |
|---|---|---|
| Context pack | `/context <product-area>` | It summarizes current evidence for one area and stops rather than inventing unsupported architecture. |
| Durable query answer | `/query <question>` again | Existing answers are saved synthesis; Echo Wiki does not silently change them. |
| Knowledge-gap note | A new evidence-backed query and an explicit review | A gap does not automatically close just because a new source was ingested. |
| Maintenance queue and lint report | `/maintain` | `/maintain` is a manual safe-maintenance command, not a scheduler or background service. |

After adding evidence for an active product area, a practical routine is:

```text
/ingest new source
/context affected-area        # if developers use a context pack
/query recurring question     # if a prior answer needs a fresh synthesis
/maintain                     # when you want the health and priority view
```

## Replacing or Removing a Source

`raw/` is append-only during normal `/ingest` and `/compile` work. Echo Wiki does **not** have a first-class “refresh this same URL” operation: the ingest workflow avoids duplicate sources, and replacing an existing raw receipt is not a normal update path.

For a true replacement—for example, a source published at the same canonical URL has materially changed—use a deliberate reconciliation workflow **only when at least one other raw source remains**:

1. Identify workspace artifacts that cite the old source or link to articles it uniquely produced.
2. Decide whether to preserve, refresh, or explicitly remove those artifacts. A rebuild will stop rather than leave a broken workspace dependency behind.
3. Manually delete the old raw receipt.
4. Run `/rebuild` to remove its compiled projection safely. If validation reports obsolete workspace artifacts, resolve those explicitly and retry.
5. Run `/ingest <url>` for the replacement source, then let `/compile` update the KB.
6. Refresh any relevant context packs or durable answers, then run `/maintain` when you want an updated maintenance view.

`/rebuild` stages and validates the entire replacement before it changes the live `wiki/` directory. It preserves workspaces, `.obsidian`, and the activity log; it does not silently repair derived workspace content that has lost its evidence.

### Current Boundary: The Only Raw Source

If the receipt being removed is the **only** raw source, `/rebuild` intentionally stops without changing the wiki. That protects the current KB from an accidental empty rebuild, but it means Echo Wiki has no supported complete remove-or-replace workflow for that last source today. Keep the receipt and its compiled output intact, and treat this as a product limitation that needs an explicit removal/replacement capability; do not try to work around it by hand-editing compiled KB articles.

## Human and Agent Responsibilities

| Actor | Do | Do not |
|---|---|---|
| Human user | Add sources through `/ingest`, write personal notes in a regular workspace, run `/index` after manual workspace changes, and review maintenance findings. | Edit KB articles directly or assume source changes propagate without a command. |
| Agent | Use `/ingest` and `/compile` for source-backed KB updates; use `/query`, `/context`, and `/maintain` for their intended derived outputs. | Write another actor’s workspace, treat a query answer as a source, or silently repair factual content during `/maintain`. |

## A Simple Freshness Routine

Use the smallest operation that matches the change:

```text
Added a source?                 /ingest
Added raw Markdown manually?    validate, then /compile <path>
Changed a workspace note?       /index
Need current developer context? /context <area>
Need a new synthesis?           /query <question>
Need a health scan?             /maintain
Removed a source?               /rebuild
```

This keeps the KB evidence-backed while preserving notes, answers, and other workspace content as deliberate, reviewable work.
