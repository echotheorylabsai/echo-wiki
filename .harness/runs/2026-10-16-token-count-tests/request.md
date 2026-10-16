Add tests for `hooks/token-count.sh` (the only hook with zero tests): word and token totals on a fixture, the empty-wiki case, and the log line it appends.
Check: `bash tests/run-tests.sh` passes with new `token-count` cases, and a deliberately wrong expected total makes it fail.
