# Ingest — Reference

Fetch content from URLs or local files and save as clean markdown in `raw/`.

## Input
- URL(s) or local file path(s)
- Optional: `source_type` override (required for podcast/video)

## Steps
1. Read `_meta/wiki.config.yaml` for allowed source types and ingestion settings
2. Check `wiki/_index.md` for existing source-summaries (avoid duplicates)
3. Detect source type from URL pattern:
   - `*.substack.com/*` → substack
   - `github.com/*` → github
   - `twitter.com/*` or `x.com/*` → tweet
   - `arxiv.org/*` or `*.pdf` → paper
   - Other URLs → blog
   - Podcast/video → user must specify explicitly
4. Fetch content via Tavily extract (`urls` parameter takes string array) or Firecrawl API
5. Clean HTML to markdown, preserve headings/code/lists/images
6. Download images to `raw/<category>/images/`
7. Write markdown to `raw/<category>/` with complete frontmatter (see schema)
8. Proceed to compile the new source

## Directory Mapping
| source_type | directory |
|---|---|
| blog | raw/blogs/ |
| paper | raw/papers/ |
| tweet | raw/people/ |
| substack | raw/substacks/ |
| github | raw/github/ |
| podcast | raw/media/ |
| video | raw/media/ |

## Filename Convention
Kebab-case from title, max 60 chars, `.md` extension.
