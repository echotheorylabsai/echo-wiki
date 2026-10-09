Add a troubleshooting page to the docs site: `docs/troubleshooting.md`, titled "Troubleshooting Validation".

It should explain the most common failures reported by `hooks/validate.sh` (for example missing required frontmatter fields, tags that do not match a domain in `_meta/wiki.config.yaml`, non-kebab-case filenames, broken wikilinks, and `sources:` paths that do not exist) and how to fix each one. Derive every failure message and rule from the actual script and schema in this repository; do not invent rules.

Link the new page in the VitePress sidebar (`docs/.vitepress/config.mts`) under the "Reference" group, after "Provider Support". Do not change other pages.
