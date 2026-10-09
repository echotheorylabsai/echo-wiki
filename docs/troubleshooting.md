# Troubleshooting Validation

`./hooks/validate.sh` is the deterministic schema check described in [Validation & Linting](/validation). It enforces `_meta/schemas/frontmatter.yaml` and reads the allowed values from `_meta/wiki.config.yaml`. When something is wrong it prints one line per problem, then a summary, and exits with status 1:

```
wiki/concepts/example.md: missing required field 'summary'
wiki/concepts/example.md: tag 'quantum' not in config domains (expected: general)
Validation failed: 2 issue(s)
```

Each line has the shape `<file>: <message>`. This page lists the messages you are most likely to see, the rule behind each one, and how to fix it. Every message and rule here comes from `hooks/validate.sh` and `_meta/schemas/frontmatter.yaml`.

| Output | Meaning |
|---|---|
| `OK: <N> files validated` | Every checked file passed. Exit status 0. |
| `Validation failed: <N> issue(s)` | At least one problem was listed above this line. Exit status 1. |

To re-check a single file while fixing it, pass its repository-relative path:

```bash
./hooks/validate.sh wiki/concepts/example.md
./hooks/validate.sh --staged     # staged .md files under wiki/ and raw/
./hooks/validate.sh --all        # every .md under wiki/ and raw/
```

Run the script from inside the repository (it locates the root with `git rev-parse --show-toplevel`, or `ECHO_WIKI_ROOT` if set).

## Which rules apply to a file

The script picks a rule set ("zone") from the file's path. Knowing the zone tells you which messages can appear.

| Zone | Path | Checks that run |
|---|---|---|
| KB article | `wiki/<entity dir>/` (directories from `entity_types` in config; default `concepts/`, `people/`, `tools/`, `sources/`) | Frontmatter shape, 11 required fields, enums, dates, tags, sources, type-specific fields, filename, wikilinks, evidence locators |
| Raw source | `raw/` | Frontmatter shape, 8 required fields, `source_type` and `ingestion_tool` enums, dates, tags, filename, at least one visible heading |
| Workspace file | `wiki/workspaces/` | Frontmatter shape, `title` and `created`, `created` date, wikilinks. Evidence locators only under `knowledge-maintenance/context/` and `<actor>/answers/` |

`wiki/_index.md`, `wiki/_backlinks.md`, `wiki/_log.md`, `.gitkeep` files and anything under `wiki/.obsidian/` are never validated.

## Fix frontmatter shape first

If the frontmatter block cannot be read, the script reports one of these messages and **skips every other check for that file**. Fix it, re-run, and the remaining problems for that file will appear.

| Message | Why it fires | Fix |
|---|---|---|
| `missing frontmatter` | Line 1 of the file is not exactly `---`. | Start the file with `---` on the very first line, with nothing before it (no blank line, no byte-order mark). |
| `unclosed frontmatter` | The file has fewer than two lines that are exactly `---`. | Add the closing `---` line after the last field. |
| `invalid frontmatter syntax` | The text between the markers is not valid YAML, is not a key/value mapping, or a key or value contains a control character. Typical causes: a stray prose line inside the block, an unclosed quote (`title: "Unclosed`), an invalid backslash escape inside double quotes (`"Invalid \q escape"`), or a malformed list (`tags: [ai,, software]`). | Use one `key: value` per line. Close every quote and bracket, quote strings that contain `:` or `#`, and write lists as `["a", "b"]`. Keep wikilinks in `related` quoted, as in the [schema examples](/schema). |
| `YAML parser unavailable (ruby is required)` | The `ruby` command is not on `PATH`. The script parses YAML with Ruby's standard library and needs no gems. | Install Ruby or add it to `PATH`. |

## Missing required fields

| Message | Why it fires | Fix |
|---|---|---|
| `missing required field '<field>'` | A key the zone requires is absent from the frontmatter. The check looks for the key, so a key that is present with an empty value passes this check (and may fail a later one). | Add the key. Required keys per zone are listed below. |
| `missing type-specific field '<field>' for type '<type>'` | A KB article whose `type` is one of the built-in types lacks a field that type requires. Custom entity types have no type-specific requirements. | Add the field listed for that type below. |

Required keys by zone:

| Zone | Required keys |
|---|---|
| KB article | `title`, `type`, `created`, `last_updated`, `last_verified`, `decay_rate`, `confidence`, `tags`, `sources`, `related`, `summary` |
| Raw source | `title`, `source_url`, `source_type`, `source_date`, `author`, `ingested`, `ingestion_tool`, `tags` |
| Workspace file | `title`, `created` |

Type-specific keys for built-in KB types:

| Type | Extra required keys |
|---|---|
| concept | `domain` |
| person | `role` |
| tool | `category`, `maintained` |
| source-summary | `source_url`, `source_type`, `author`, `source_date` |

See [Frontmatter Schema](/schema) for complete examples of each zone.

## Invalid enum values

Enum fields must match one of the allowed values exactly. Matching is exact and case-sensitive; the built-in values are all lowercase.

| Message | Where | Fix |
|---|---|---|
| `invalid type '<value>' (expected: <entity type names>)` | KB article | Use a `name` from `entity_types` in `_meta/wiki.config.yaml` (default `concept`, `person`, `tool`, `source-summary`). A common slip is using the directory (`concepts`) or the label (`Concepts`) instead of the name. |
| `invalid decay_rate '<value>' (expected: fast\|medium\|slow)` | KB article | Use `fast`, `medium` or `slow`. |
| `invalid confidence '<value>' (expected: high\|medium\|speculative)` | KB article | Use `high`, `medium` or `speculative`. |
| `invalid category '<value>' (expected: framework\|platform\|service\|product)` | KB article with `type: tool` | Use `framework`, `platform`, `service` or `product`. |
| `invalid source_type '<value>' (expected: <source types>)` | Raw source, and KB article with `type: source-summary` | Use a value from `source_types` in `_meta/wiki.config.yaml` (default `internal`, `blog`, `paper`, `tweet`, `substack`, `github`, `podcast`, `video`). To allow a new type, add it to the config and to the `source_type` lists in `_meta/schemas/frontmatter.yaml`. |
| `invalid ingestion_tool '<value>' (expected: tavily\|firecrawl\|local)` | Raw source | Use `tavily`, `firecrawl` or `local`. |

## Invalid dates

| Message | Why it fires | Fix |
|---|---|---|
| `invalid date format in '<field>' (expected YYYY-MM-DD, got '<value>')` | A date field is not four digits, a hyphen, two digits, a hyphen, two digits. Only the shape is checked. | Write dates as `2026-04-04`, quoted or unquoted. Values such as `04/04/2026` or `April 4, 2026` fail. |

Date fields that are checked: `created`, `last_updated` and `last_verified` in KB articles (plus `source_date` for `source-summary`); `source_date` and `ingested` in raw sources; `created` in workspace files.

## Tags not in config domains

| Message | Why it fires | Fix |
|---|---|---|
| `tag '<tag>' not in config domains (expected: <domains>)` | A value in `tags` does not equal the `name` of a domain under `domains:` in `_meta/wiki.config.yaml`. The default config defines only `general`. Matching is against `name`, not `label`, and is case-sensitive. | Change the tag to a configured domain name, or add the domain to the config (see [Configuration](/configuration)). |

Tags are checked in KB articles and raw sources, not in workspace files. If `domains:` in the config is empty, any tag is accepted.

## Filenames that are not kebab-case

| Message | Why it fires | Fix |
|---|---|---|
| `filename not kebab-case (expected: lowercase-with-hyphens.md)` | The file name does not match `^[a-z0-9]+(-[a-z0-9]+)*\.md$`: only lowercase letters a–z, digits and single hyphens, ending in `.md`. Uppercase letters, underscores, spaces, extra dots, and leading, trailing or doubled hyphens all fail. | Rename the file, for example `Bad_Name.md` to `bad-name.md`. Then update any wikilink that pointed at the old name and run `./hooks/reindex.sh`. |
| `filename exceeds 60 characters` | The file name, including `.md`, is longer than 60 characters. | Shorten the name and fix wikilinks as above. |

Filenames are checked in KB articles and raw sources, not in workspace files.

## Broken wikilinks

Every `[[...]]` in a KB article or workspace file is checked, both in the frontmatter (such as `related`) and in the visible body. The script drops any display text after `|` and any anchor after `#`, then expects the file `wiki/<target>.md` to exist.

| Message | Why it fires | Fix |
|---|---|---|
| `broken wikilink [[<target>]]` | `wiki/<target>.md` does not exist. Common causes: the type directory is missing (`[[event-sourcing]]` instead of `[[concepts/event-sourcing]]`), the link includes `.md`, the directory or name is misspelled, the target article has not been compiled yet, or a wikilink was used where a plain path belongs (for example in `sources`). | Write links vault-relative from `wiki/`, with the directory and without `.md`: `[[concepts/event-sourcing\|Event Sourcing]]`. Create or compile the missing target, or remove the link. |
| `wikilink escapes wiki/: [[<target>]]` | The target starts with `/`, contains `../` or `./`, or resolves through a symlink to a file outside `wiki/`. | Use a plain path relative to `wiki/`, such as `concepts/name`. |

Wikilinks inside fenced code blocks and HTML comments in the body are not checked; wikilinks in the frontmatter always are. Raw sources are not checked for wikilinks.

## Source paths that do not exist

The `sources` list in a KB article holds plain strings, not wikilinks. Each entry is a path from the repository root to a file inside `raw/`, such as `raw/blogs/post.md`.

| Message | Why it fires | Fix |
|---|---|---|
| `sources list is empty` | The `sources` key exists but has no entries (`sources: []`). | List at least one raw file. |
| `source path does not exist: <path>` | No file exists at that path from the repository root. Common causes: wikilink syntax (`[[raw/blogs/post]]`), a missing `.md`, a path relative to `wiki/` instead of the root, a typo, or a raw file that was removed. | Use the exact path of an existing file under `raw/`, including `.md`. If the raw file was deleted on purpose, run `/rebuild` so the article is regenerated from the remaining sources. |
| `source path escapes raw/: <path>` | The file exists but is not inside `raw/`: the path uses `..`, points elsewhere, or goes through a symlink that leaves `raw/`. | Cite only files that live under `raw/`. |

## Evidence locators

KB articles, context packs under `wiki/workspaces/knowledge-maintenance/context/`, and files under `wiki/workspaces/<actor>/answers/` must contain at least one visible line of the form `Evidence: raw/<path>.md#<exact heading>`. Lines inside fenced code blocks, HTML comments or raw HTML blocks do not count.

| Message | Why it fires | Fix |
|---|---|---|
| `missing evidence locator` | No visible `Evidence:` line was found in the body. | Add `Evidence: raw/<path>.md#<heading>` after the paragraph it supports. |
| `invalid evidence locator '<line>' (expected: Evidence: raw/<path>.md#<exact heading>)` | The locator does not start with `raw/`, does not end in `.md` before the `#`, or has nothing after the `#`. | Match the shape exactly. |
| `evidence source does not exist: <path>` | The raw file named before the `#` is missing. | Point at an existing raw file. |
| `evidence source escapes raw/: <path>` | The path leaves `raw/` through `..`, `./` or a symlink. | Cite only files under `raw/`. |
| `evidence source not listed in sources: <path>` | In a KB article, the cited raw file is not in the frontmatter `sources` list. | Add the raw path to `sources`. |
| `evidence heading does not exist: <path>#<heading>` | The raw file has no visible Markdown heading with exactly that text. Headings inside code fences, HTML comments or the raw file's frontmatter do not count. | Copy the heading text exactly from the raw file, without the leading `#` marks. |
| `missing citable Markdown heading` | A raw source has no visible Markdown heading, so nothing in it can be cited. | Add a heading such as `## Content` before the body. See [Upgrading an Existing Wiki](/validation#upgrading-an-existing-wiki). |

## Structure errors

These lines start with `structure:` instead of a file path. They are checked before any file and usually mean the repository layout is incomplete.

| Message | Why it fires | Fix |
|---|---|---|
| `invalid _meta/wiki.config.yaml` | The config is not valid YAML, has no non-empty `entity_types` list, or an entity type lacks `name`, `dir` or `label`, or two entries share a name or dir. | Repair the config; see [Configuration](/configuration). |
| `repository root path must be a real directory: <path>` | `_meta`, `raw` or `wiki` is missing at the repository root or is a symlink. | Create the directory, or replace the symlink with a real directory. |
| `required path missing: <path>` | `wiki/_index.md`, `wiki/_backlinks.md`, `wiki/workspaces/` or a configured KB directory does not exist. | Run `./hooks/reindex.sh` to regenerate the two index files; create missing directories. |
| `unsafe configured KB directory: <dir>` | An entity type's `dir` is not a single kebab-case path component, or is the reserved name `workspaces`. | Use a plain lowercase name such as `decisions`. |
| `configured KB directory must be a real direct child: wiki/<dir>` | The configured KB directory is a symlink or otherwise not a real directory directly under `wiki/`. | Replace it with a real directory. |
| `managed path may not be a symlink` | A symlink exists somewhere under `wiki/` or `raw/`, or a path passed on the command line is a symlink. | Replace the symlink with a real file or directory. |
| `path not found` | A path passed on the command line does not exist. | Check the spelling; paths are relative to the repository root. |

## A file was not checked

The script prints a note on standard error for Markdown files it cannot classify, and does not count them as validated. These notes are not failures: the file is simply not checked.

| Message | Why it fires | Fix |
|---|---|---|
| `NOTE: not a KB or workspace path, skipping: <path>` | The file is under `wiki/` but not inside a configured entity directory or `wiki/workspaces/`. | Move it into a configured directory or a workspace, or add the entity type to `_meta/wiki.config.yaml`. |
| `NOTE: outside wiki/ and raw/, skipping: <path>` | The file is outside both validated zones. | Only files under `wiki/` and `raw/` are validated. |

## After fixing

Re-run `./hooks/validate.sh` on the file, then `./hooks/validate.sh --all` before committing. If the [pre-commit hook](/validation#pre-commit-hook) is installed it runs the full check for you and blocks the commit until it passes. For problems a script cannot see, such as contradictions or stale content, run `/lint`.
