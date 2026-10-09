Add a machine-readable output mode to the schema validator: `hooks/validate.sh --json`.

- `--json` combines with the existing modes (`--all`, `--staged`, explicit paths) and prints one JSON object on stdout: the number of files validated, and a list of violations, each with the file path and the problem message. Exit codes stay exactly as they are today (0 = clean, 1 = violations).
- Without `--json`, output must be byte-for-byte unchanged.
- The script must stay Bash 3.2 compatible and must not add a new runtime dependency (no jq, no Python).
- Add tests for the new mode to the repo's existing test runner (`tests/run-tests.sh`), covering a clean run and a run with violations, including a problem message that contains a double quote.
- Document the flag wherever `validate.sh` usage is documented for users.

Process: I want to review the plan before any code is written. Stop after the plan phase and wait; I will start a new session to approve it.
