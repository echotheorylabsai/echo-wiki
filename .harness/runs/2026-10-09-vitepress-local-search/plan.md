## Goal

Turn on VitePress's built-in `local` search in `docs/.vitepress/config.mts` so the docs site has an offline search box covering every docs page, with no external service and no new dependency.

## Outcome

- The built site ships a local search index covering all docs pages, including Troubleshooting.
- `docs/superpowers/` stays out of the index (already excluded from the build by `srcExclude`; no such pages are tracked today).
- `package.json` / `package-lock.json` unchanged; `npm run docs:build` passes.

## Acceptance checks

### C1 — Docs site still builds
Expected: clean install and `npm run docs:build` exit 0.
```sh
npm ci && npm run docs:build
```

### C2 — Built search index has a Troubleshooting-only word and no superpowers content
Expected: the local search index chunk exists, contains the word `stray` (only in `docs/troubleshooting.md`) and the troubleshooting page, and has no `superpowers` text.
```sh
npm ci >/dev/null 2>&1 && npm run docs:build >/dev/null 2>&1 && ls docs/.vitepress/dist/assets/chunks/@localSearchIndexroot.*.js && grep -qw stray docs/.vitepress/dist/assets/chunks/@localSearchIndexroot.*.js && grep -q troubleshooting docs/.vitepress/dist/assets/chunks/@localSearchIndexroot.*.js && ! grep -qi superpowers docs/.vitepress/dist/assets/chunks/@localSearchIndexroot.*.js
```

### C3 — Config uses the local provider and no dependency was added
Expected: config sets `provider: 'local'`; package files identical to `origin/main`.
```sh
grep -q "provider: 'local'" docs/.vitepress/config.mts && git diff --quiet origin/main -- package.json package-lock.json
```

## Tier

S — one-sentence diff: add `search: { provider: 'local' }` to the VitePress theme config.

## Source

prompt
