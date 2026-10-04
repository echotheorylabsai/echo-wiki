---
title: Fresh repository onboarding
---

# Fresh repository

1. Confirm destination, wiki name/purpose, initial domains, and human workspace. Infer reasonable defaults from the request; use the built-in article types initially unless specific types are needed. Keep `source-summary` in `sources/`.
2. Verify Git, Bash and Ruby are available. Start with local Markdown; API keys and Node.js are not required for that path. URL/PDF extraction requires an available agent tool; do not promise unconfigured providers.
3. Preview and apply from the upstream checkout (replace the destination with its absolute path):

   ```bash
   ruby .claude/skills/onboard/scripts/bootstrap.rb --check /path/to/company-kb
   ruby .claude/skills/onboard/scripts/bootstrap.rb --apply /path/to/company-kb
   ```

   A fresh repo may still contain instruction/ignore files; preserve and integrate them in the shared finish steps. Do not copy upstream `.git`, `.github`, `package.json`, source knowledge, or secrets into the instance.
4. Continue with the shared finish reference linked from SKILL.md. A clean install is only the first milestone; verify a selected real source before claiming the knowledge workflow is ready.
