#!/bin/bash
# Health check script
# Sử dụng: ./scripts/health_check.sh [host] [port]

HOST=${1:-localhost}
PORT=${2:-8000}
URL="http://${HOST}:${PORT}"

echo "Checking health of $URL..."

# Health check
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$URL/health")

if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo "✓ Health check: OK"
else
    echo "✗ Health check: FAILED (HTTP $HEALTH_RESPONSE)"
    exit 1
fi

# Status check
STATUS_RESPONSE=$(curl -s "$URL/api/status")

if [ $? -eq 0 ]; then
    echo "✓ Status endpoint: OK"
    echo "$STATUS_RESPONSE" | python -m json.tool
else
    echo "✗ Status endpoint: FAILED"
    exit 1
fi

echo ""
echo "All checks passed!"
