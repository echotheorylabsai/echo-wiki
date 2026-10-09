# Plan — 2026-10-09-skills-nav-link

## Goal

Add a top navigation link "Skills" pointing to `/skills` in the VitePress docs site config
`docs/.vitepress/config.mts`, placed between the existing "Guide" and "Configuration" nav items.
Change nothing else.

## Outcome

The `themeConfig.nav` array in `docs/.vitepress/config.mts` reads, in order: Guide, Skills, Configuration,
GitHub. The Skills entry is exactly `{ text: 'Skills', link: '/skills' }`. The diff against the integration
branch (`origin/main`), excluding `.harness/`, is one added line in that single file. The target page
`docs/skills.md` already exists, so the link resolves.

## Acceptance checks

### C1 — nav array has Skills (/skills) immediately after Guide and immediately before Configuration
Expected: the parsed nav items are printed as JSON and the command exits 0 only when the entry
`{ text: 'Skills', link: '/skills' }` sits directly between the Guide and Configuration entries.
```sh
node -e "
const s = require('fs').readFileSync('docs/.vitepress/config.mts', 'utf8');
const m = s.match(/nav:\s*\[([^\]]*)\]/);
if (!m) { console.error('nav array not found'); process.exit(1); }
const items = [...m[1].matchAll(/\{\s*text:\s*'([^']*)',\s*link:\s*'([^']*)'\s*\}/g)].map(x => ({ text: x[1], link: x[2] }));
console.log(JSON.stringify(items));
const i = items.findIndex(x => x.text === 'Guide');
const ok = i >= 0 && items[i+1] && items[i+1].text === 'Skills' && items[i+1].link === '/skills' && items[i+2] && items[i+2].text === 'Configuration';
process.exit(ok ? 0 : 1);
"
```

### C2 — nothing else changed: the code diff against origin/main is exactly one added line in config.mts
Expected: `git diff --numstat` from `origin/main` to `HEAD`, excluding `.harness/`, is exactly
`1 0 docs/.vitepress/config.mts` (one insertion, zero deletions, one file); the command exits 0 only then.
```sh
out="$(git diff --numstat origin/main HEAD -- . ':(exclude).harness' | tr '\t' ' ')"; echo "numstat now: [$out]"; test "$out" = "1 0 docs/.vitepress/config.mts"
```

## Tier

S — the diff fits in one sentence: insert one nav entry line in one config file.

## Source

prompt
