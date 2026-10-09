Make echo-wiki's CI prove that `./hooks/validate.sh --json` prints valid JSON.

- Add a step to the `validate` job in `.github/workflows/ci.yml` that runs `./hooks/validate.sh --all --json` and fails the job when its output is not valid JSON. The exit status alone is not enough: empty or garbled output must fail the step too.
- Use a JSON parser that is already on the runner; add no new action or dependency.
- Do not change the other jobs or `deploy-docs.yml`.
- Acceptance must include one observed check: CI passes on this task's own PR (`gh pr checks`).
