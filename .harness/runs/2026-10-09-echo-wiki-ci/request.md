Add a pull-request CI workflow to echo-wiki, so every PR and every push to `main` runs the repository's own checks on GitHub Actions.

- New workflow `.github/workflows/ci.yml`; do not change `deploy-docs.yml`.
- Jobs: (1) `bash tests/run-tests.sh` (hook test suite), (2) `./hooks/validate.sh --all` on the repository's own wiki content if that is meaningful here (check what the repo expects; if it is not meaningful, say why and skip it), (3) `npm ci && npm run docs:build`.
- The hook scripts claim Bash 3.2 compatibility: run the hook test suite on both `ubuntu-latest` and `macos-latest` (macOS ships Bash 3.2).
- Pin each action to a major version (as `deploy-docs.yml` does); least-privilege `permissions: contents: read`; cancel superseded runs on the same branch.
- Document the CI in the contributor-facing docs where checks are already described (find the right page; one short paragraph).
- Acceptance must include one observed check: the new workflow runs on this task's own PR and every job passes (`gh pr checks`).
