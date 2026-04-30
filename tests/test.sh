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
echo "=== Test 4: CVE-2026-33320 fix — YAML alias expansion bomb is rejected ==="
# 10 *c, each *c expands 10 *b, each *b expands 10 *a → ~1110 alias resolutions,
# exceeding the patched maxExpansionBudget=1000. A vulnerable build would hang or OOM;
# the fixed build must exit non-zero.
ALIAS_BOMB='a: &a [1]
b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a,*a]
c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b,*b]
d: [*c,*c,*c,*c,*c,*c,*c,*c,*c,*c]'
if docker run --rm -i "$IMAGE" -i yaml 'd' <<< "$ALIAS_BOMB" 2>/dev/null; then
    echo "FAIL: dasel accepted the alias bomb — CVE-2026-33320 may not be fixed"
    exit 1
else
    echo "PASS: dasel correctly rejected the YAML alias bomb (CVE-2026-33320 is fixed)"
fi

echo ""
echo "=== All tests passed ==="
