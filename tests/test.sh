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
echo "=== All tests passed ==="
