#!/bin/bash
# Lambda test runner (simulates GitHub Actions workflow locally)
set -e

LAMBDA_FUNCTION_NAME="playwright-serverless-dev-run-tests"
AWS_REGION="us-east-1"

tests=(
  "tests/simple.js"
  "tests/demo.lambda.js"
  "tests/example.lambda.js"
  "tests/api.lambda.js"
  "tests/apiChallenge.lambda.js"
  "tests/demo-todo-app.lambda.js"
  "tests/api-gravity.lambda.js"
)

failed=0
passed=0
total=${#tests[@]}

echo "🚀 Starting Lambda Playwright Tests"
echo "Function: $LAMBDA_FUNCTION_NAME"
echo "Region: $AWS_REGION"
echo "Total tests: $total"
echo ""

for test in "${tests[@]}"; do
  echo "🧪 Running: $test"
  
  # Create payload
  echo "{\"body\":{\"testMatch\":\"$test\"}}" > test-payload.json
  
  # Invoke Lambda
  aws lambda invoke \
    --function-name $LAMBDA_FUNCTION_NAME \
    --cli-binary-format raw-in-base64-out \
    --payload file://test-payload.json \
    --region $AWS_REGION \
    response.json > /dev/null 2>&1
  
  # Parse response
  status=$(jq -r '.statusCode' response.json)
  if [ "$status" = "200" ]; then
    body=$(jq -r '.body' response.json)
    success=$(echo "$body" | jq -r '.success')
    duration=$(echo "$body" | jq -r '.duration')
    
    if [ "$success" = "true" ]; then
      echo "✅ Passed - Duration: ${duration}ms"
      ((passed++))
    else
      error=$(echo "$body" | jq -r '.error')
      echo "❌ Failed - $error"
      ((failed++))
    fi
  else
    echo "❌ Lambda invocation failed with status: $status"
    ((failed++))
  fi
  
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "Total:   $total"
echo "Passed:  $passed"
echo "Failed:  $failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $failed -gt 0 ]; then
  echo "❌ Some tests failed. Exiting with code 1."
  exit 1
else
  echo "✅ All tests passed!"
  exit 0
fi
