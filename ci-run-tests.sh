#!/bin/bash
# Cross-platform CI/CD test runner for Lambda Playwright tests
# Usage: ./ci-run-tests.sh

set -e  # Exit on error

# Configuration
LAMBDA_FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-playwright-serverless-dev-run-tests}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Test files to run
tests=(
  "tests/simple.js"
  "tests/demo.lambda.js"
  "tests/example.lambda.js"
  "tests/api.lambda.js"
  "tests/apiChallenge.lambda.js"
  "tests/demo-todo-app.lambda.js"
  "tests/api-gravity.lambda.js"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
failed=0
passed=0
total=${#tests[@]}

echo -e "${CYAN}🚀 Starting Lambda Playwright Tests${NC}"
echo -e "Function: ${LAMBDA_FUNCTION_NAME}"
echo -e "Region: ${AWS_REGION}"
echo -e "Total tests: ${total}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo -e "${RED}❌ AWS CLI is not installed${NC}"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo -e "${YELLOW}⚠️  jq is not installed. Installing...${NC}"
  # Try to install jq (works on most Linux systems)
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y jq
  elif command -v yum &> /dev/null; then
    sudo yum install -y jq
  elif command -v brew &> /dev/null; then
    brew install jq
  else
    echo -e "${RED}❌ Cannot install jq automatically. Please install it manually.${NC}"
    exit 1
  fi
fi

# Run each test
for test in "${tests[@]}"; do
  echo -e "${CYAN}🧪 Running: ${test}${NC}"
  
  # Create payload
  echo "{\"body\":{\"testMatch\":\"${test}\"}}" > test-payload.json
  
  # Invoke Lambda
  if aws lambda invoke \
    --function-name "${LAMBDA_FUNCTION_NAME}" \
    --cli-binary-format raw-in-base64-out \
    --payload file://test-payload.json \
    --region "${AWS_REGION}" \
    response.json > /dev/null 2>&1; then
    
    # Parse response
    status=$(jq -r '.statusCode' response.json 2>/dev/null || echo "0")
    
    if [ "$status" = "200" ]; then
      body=$(jq -r '.body' response.json)
      success=$(echo "$body" | jq -r '.success' 2>/dev/null || echo "false")
      duration=$(echo "$body" | jq -r '.duration' 2>/dev/null || echo "0")
      
      if [ "$success" = "true" ]; then
        echo -e "${GREEN}✅ Passed${NC} - Duration: ${duration}ms"
        ((passed++))
      else
        error=$(echo "$body" | jq -r '.error // "Unknown error"' 2>/dev/null || echo "Test failed")
        echo -e "${RED}❌ Failed${NC} - ${error}"
        ((failed++))
      fi
    else
      echo -e "${RED}❌ Lambda invocation failed with status: ${status}${NC}"
      ((failed++))
    fi
  else
    echo -e "${RED}❌ Failed to invoke Lambda function${NC}"
    ((failed++))
  fi
  
  echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}📊 Test Summary${NC}"
echo -e "Total:   ${total}"
echo -e "${GREEN}Passed:  ${passed}${NC}"
echo -e "${RED}Failed:  ${failed}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Exit with error if any tests failed
if [ $failed -gt 0 ]; then
  echo -e "${RED}❌ Some tests failed. Exiting with code 1.${NC}"
  exit 1
else
  echo -e "${GREEN}✅ All tests passed!${NC}"
  exit 0
fi

