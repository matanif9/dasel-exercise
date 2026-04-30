#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-dasel:test-amd64}"

echo "=== Test 1: binary is present and runnable ==="
docker run --rm "$IMAGE" version
echo "PASS"

echo ""
echo "=== Test 2: JSON querying (real behavior) ==="
OUTPUT=$(docker run --rm -i "$IMAGE" -i json 'name' <<< '{"name":"Alice","age":30}')
echo "Output: $OUTPUT"
if echo "$OUTPUT" | grep -q "Alice"; then
    echo "PASS"
else
    echo "FAIL: expected 'Alice', got: $OUTPUT"
    exit 1
fi

echo ""
echo "=== Test 3: YAML modification (real behavior) ==="
OUTPUT=$(docker run --rm -i "$IMAGE" -i yaml --root 'environment = "production"' <<< 'environment: staging')
echo "Output: $OUTPUT"
if echo "$OUTPUT" | grep -q "production"; then
    echo "PASS"
else
    echo "FAIL: expected 'production', got: $OUTPUT"
    exit 1
fi

echo ""
echo "=== Test 4: CVE-2026-33320 fix — YAML alias bomb triggers budget error ==="
# 10 *c, each *c expands 10 *b, each *b expands 10 *a → ~1110 alias resolutions,
# exceeding the patched maxExpansionBudget=1000.
# We capture stderr and assert the specific error the patch emits. A non-zero exit
# alone would not distinguish the fix from an OOM crash; the error string does.
ALIAS_BOMB='a: &a [1]
b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a,*a]
c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b,*b]
d: [*c,*c,*c,*c,*c,*c,*c,*c,*c,*c]'
ERR=$(docker run --rm -i "$IMAGE" -i yaml 'd' <<< "$ALIAS_BOMB" 2>&1 || true)
echo "Output: $ERR"
if echo "$ERR" | grep -q "yaml expansion budget exceeded"; then
    echo "PASS: dasel emitted the expected budget-exceeded error (CVE-2026-33320 is fixed)"
else
    echo "FAIL: expected 'yaml expansion budget exceeded', got: $ERR"
    exit 1
fi

echo ""
echo "=== All tests passed ==="
