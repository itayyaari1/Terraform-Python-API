#!/bin/bash

# Verification script for deployed API
# Usage: ./verify_deployment.sh <PUBLIC_IP>

set -e

PUBLIC_IP=$1

if [ -z "$PUBLIC_IP" ]; then
    echo "Usage: ./verify_deployment.sh <PUBLIC_IP>"
    echo "Or get IP from Terraform: ./verify_deployment.sh \$(terraform output -raw public_ip)"
    exit 1
fi

API_URL="http://${PUBLIC_IP}:5000"

echo "=========================================="
echo "Verifying API Deployment"
echo "=========================================="
echo "Public IP: $PUBLIC_IP"
echo "API URL: $API_URL"
echo ""

# Wait for API to be ready (with timeout)
echo "Waiting for API to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s -f "$API_URL/status" > /dev/null 2>&1; then
        echo "✅ API is ready!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting..."
    sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "❌ API did not become ready after $MAX_ATTEMPTS attempts"
    echo "Check EC2 instance logs: ssh ec2-user@$PUBLIC_IP 'sudo docker logs python-api'"
    exit 1
fi

echo ""
echo "=========================================="
echo "Testing Endpoints"
echo "=========================================="

# Test 1: GET /status
echo ""
echo "1. Testing GET /status"
echo "----------------------"
STATUS_RESPONSE=$(curl -s "$API_URL/status")
echo "$STATUS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$STATUS_RESPONSE"

# Test 2: POST /update
echo ""
echo "2. Testing POST /update"
echo "----------------------"
UPDATE_RESPONSE=$(curl -s -X POST "$API_URL/update" \
    -H "Content-Type: application/json" \
    -d '{"counter": 42, "message": "Deployed on EC2!"}')
echo "$UPDATE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$UPDATE_RESPONSE"

# Test 3: GET /status (after update)
echo ""
echo "3. Testing GET /status (after update)"
echo "----------------------"
STATUS_RESPONSE=$(curl -s "$API_URL/status")
echo "$STATUS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$STATUS_RESPONSE"

# Test 4: GET /logs
echo ""
echo "4. Testing GET /logs"
echo "----------------------"
LOGS_RESPONSE=$(curl -s "$API_URL/logs?page=1&limit=5")
echo "$LOGS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$LOGS_RESPONSE"

# Test 5: Validation error
echo ""
echo "5. Testing validation error (should return 400)"
echo "----------------------"
ERROR_RESPONSE=$(curl -s -X POST "$API_URL/update" \
    -H "Content-Type: application/json" \
    -d '{}')
echo "$ERROR_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$ERROR_RESPONSE"

echo ""
echo "=========================================="
echo "✅ Verification Complete!"
echo "=========================================="
echo ""
echo "API Documentation: $API_URL/docs"
echo "Status Endpoint: $API_URL/status"
echo ""
echo "You can test the API in your browser:"
echo "  - Interactive Docs: $API_URL/docs"
echo "  - Status: $API_URL/status"
echo "  - Logs: $API_URL/logs"

