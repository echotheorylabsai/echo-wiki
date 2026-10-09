Add a troubleshooting entry to `docs/troubleshooting.md` for a commit that the repository's pre-commit hook blocks, then put the failure sections in alphabetical order.

- New `##` section: what the pre-commit hook checks, what its failure output looks like, and how to fix the files and commit again. Derive everything from the hook script and its install instructions in this repository; do not invent behaviour. Do not recommend skipping the hook.
- Order the `##` sections alphabetically by heading, except keep "Which rules apply to a file" first and "After fixing" last.
- Keep every existing table, message and fact exactly as it is. Do not change any other page.
