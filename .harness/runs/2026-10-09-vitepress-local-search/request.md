Turn on VitePress's built-in local search for the docs site (`docs/.vitepress/config.mts`), so the site shows a search box that searches every docs page offline, with no external service.

- Use VitePress's own `local` search provider; no new dependency.
- Exclude the `docs/superpowers/` pages from the search index if the site builds them.
- `npm run docs:build` must still pass.
- Acceptance includes one observed check: build the site and confirm the search index contains a word that appears only on the Troubleshooting page, and none of the `superpowers/` content.
