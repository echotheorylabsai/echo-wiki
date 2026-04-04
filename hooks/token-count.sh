#!/usr/bin/env bash
# Echo Wiki — Token Count Estimator
# Counts words across raw/ and compiled/, estimates tokens (words x 1.3).
# Usage: ./hooks/token-count.sh
# Also usable as post-commit hook (informational, never blocks).
set -euo pipefail

WIKI_ROOT="$(git rev-parse --show-toplevel)"
DATE=$(date +%Y-%m-%d)

count_words() {
    find "$1" -name '*.md' -type f -exec cat {} + 2>/dev/null | wc -w | tr -d ' '
}

RAW_WORDS=$(count_words "$WIKI_ROOT/raw")
COMPILED_WORDS=$(count_words "$WIKI_ROOT/compiled")
TOTAL_WORDS=$((RAW_WORDS + COMPILED_WORDS))

RAW_TOKENS=$((RAW_WORDS * 13 / 10))
COMPILED_TOKENS=$((COMPILED_WORDS * 13 / 10))
TOTAL_TOKENS=$((TOTAL_WORDS * 13 / 10))

# Calculate percentage of 1M context window
if [ "$TOTAL_TOKENS" -eq 0 ]; then
    PCT="0.0"
else
    PCT=$(echo "scale=1; $TOTAL_TOKENS * 100 / 1000000" | bc)
    [[ "$PCT" == .* ]] && PCT="0$PCT"
fi

OUTPUT="[$DATE] Wiki Token Estimate
  raw/        $RAW_WORDS words  ~  $RAW_TOKENS tokens
  compiled/   $COMPILED_WORDS words  ~  $COMPILED_TOKENS tokens
  TOTAL       $TOTAL_WORDS words  ~  $TOTAL_TOKENS tokens

  Context usage: ~${PCT}% of 1M window"

echo "$OUTPUT"

# Append to log (git-ignored)
LOG_DIR="$WIKI_ROOT/output/reports"
mkdir -p "$LOG_DIR"
echo "$OUTPUT" >> "$LOG_DIR/token-count.log"
echo "" >> "$LOG_DIR/token-count.log"
