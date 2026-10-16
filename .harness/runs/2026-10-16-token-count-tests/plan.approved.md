## Goal
Add regression tests for hooks/token-count.sh.

## Outcome
The hook suite checks fixture word/token totals, empty directories, and appended log entries without changing the hook.

## Acceptance checks

### C1 — Hook suite includes passing token-count cases
Expected: All tests pass, including token-count totals, empty-wiki and log assertions.
```sh
bash tests/run-tests.sh
```

### C2 — A deliberately wrong total fails the suite
Expected: Mutating the expected total produces a token-count failure and a nonzero suite exit.
```sh
python3 - <<'PYTEST'
from pathlib import Path
import subprocess, tempfile
source = Path('tests/run-tests.sh').read_text()
needle = '  TOTAL       10 words  ~  13 tokens'
assert source.count(needle) == 1
with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', dir='tests') as mutated:
    mutated.write(source.replace(needle, '  TOTAL       11 words  ~  13 tokens'))
    mutated.flush()
    result = subprocess.run(['bash', mutated.name], capture_output=True, text=True)
    assert result.returncode != 0, result.stdout
    assert 'not ok - token-count populated: exact word and token totals' in result.stdout, result.stdout
    print('Wrong expected total correctly fails token-count assertion and suite')
PYTEST
```

## Tier
S — Add token-count coverage to the existing shell test runner.

## Source
prompt — request.md

## Decisions
2026-10-16 · Codex/GPT-6 · triage — Choose S; one test-runner change covers the hook. Why: Existing helpers support isolated fixtures.
2026-10-16 · Codex/GPT-6 · triage — Merge risk is low. Why: Tests and task records only; no production behavior or data changes.
