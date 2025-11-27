# How to Run Tests in Lambda Function

This guide explains the different methods to run your Playwright tests on AWS Lambda.

## Prerequisites

1. ✅ AWS credentials configured
2. ✅ Lambda function deployed (`playwright-serverless-dev-run-tests`)
3. ✅ Test files in the `tests/` directory

---

## Method 1: One-Line Script (Quickest) ⚡

Run all tests with a single command:

```powershell
.\run-tests-simple.ps1
```

**What it does:**
- Runs all test files sequentially
- Shows status and duration for each test
- Simple and fast

---

## Method 2: Using Serverless Runner (Recommended for Batch Processing)

This method runs all tests automatically using the serverless-runner orchestrator.

### Step 1: Navigate to serverless-runner directory
```powershell
cd serverless-runner
```

### Step 2: Install dependencies (if not already done)
```powershell
npm install
```

### Step 3: Run all tests
```powershell
npm start
```

**What it does:**
- Finds all test files matching the pattern in `serverless-runner/index.js`
- Runs tests in batches (5 concurrent tests by default)
- Shows progress and results for each test
- Displays summary at the end

### With Output Logging
```powershell
# From project root
.\run-tests-with-output.ps1
```
This saves the output to `test-results.log`

---

## Method 3: Using AWS CLI (Single Test)

Run a single test file directly using AWS CLI.

### Step 1: Create test payload
Create or edit `test-payload.json`:
```json
{
  "body": {
    "testMatch": "tests/simple.js"
  }
}
```

### Step 2: Invoke Lambda function
```powershell
& 'C:\Program Files\Amazon\AWSCLIV2\aws.exe' lambda invoke `
  --function-name playwright-serverless-dev-run-tests `
  --cli-binary-format raw-in-base64-out `
  --payload file://test-payload.json `
  response.json
```

### Step 3: Check response
```powershell
Get-Content response.json | ConvertFrom-Json
```

---

## Method 4: Using AWS CLI (Multiple Tests)

Run multiple tests in a loop.

### PowerShell Script
```powershell
$testFiles = @(
  'tests/simple.js',
  'tests/demo.lambda.js',
  'tests/example.lambda.js',
  'tests/api.lambda.js',
  'tests/apiChallenge.lambda.js',
  'tests/demo-todo-app.lambda.js',
  'tests/api-gravity.lambda.js'
)

foreach ($testFile in $testFiles) {
  Write-Host "🧪 Running: $testFile" -ForegroundColor Cyan
  
  # Create payload
  $payload = @{
    body = @{
      testMatch = $testFile
    }
  } | ConvertTo-Json -Depth 3
  
  $payload | Out-File -FilePath test-payload.json -Encoding utf8
  
  # Invoke Lambda
  & 'C:\Program Files\Amazon\AWSCLIV2\aws.exe' lambda invoke `
    --function-name playwright-serverless-dev-run-tests `
    --cli-binary-format raw-in-base64-out `
    --payload file://test-payload.json `
    "response-$($testFile.Replace('/', '-').Replace('.', '-')).json"
  
  # Show result
  $result = Get-Content "response-$($testFile.Replace('/', '-').Replace('.', '-')).json" | ConvertFrom-Json
  Write-Host "   Status: $($result.statusCode)" -ForegroundColor $(if ($result.statusCode -eq 200) { 'Green' } else { 'Red' })
  
  if ($result.body) {
    $body = $result.body | ConvertFrom-Json
    Write-Host "   Success: $($body.success)" -ForegroundColor $(if ($body.success) { 'Green' } else { 'Red' })
    Write-Host "   Duration: $($body.duration)ms" -ForegroundColor Yellow
  }
}
```

---

## Method 5: Using Make (Linux/Mac)

If you have Make installed:

```bash
make test-serverless
```

---

## Method 6: Using HTTP Endpoint

If your Lambda has an HTTP API Gateway endpoint configured, you can invoke it via HTTP POST.

### Using curl
```powershell
$payload = @{
  body = @{
    testMatch = "tests/simple.js"
  }
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "https://YOUR_API_GATEWAY_URL/" `
  -Method Post `
  -Body $payload `
  -ContentType "application/json"
```

---

## Test File Format

Your test files should export a function that receives a `page` object:

```javascript
// tests/example.lambda.js
module.exports = async (page) => {
  await page.goto('https://example.com');
  const title = await page.title();
  
  if (title !== 'Example Domain') {
    throw new Error(`Expected "Example Domain" but got "${title}"`);
  }
  
  return {
    success: true,
    duration: Date.now() - startTime
  };
};
```

---

## Response Format

Successful response:
```json
{
  "statusCode": 200,
  "body": "{\"success\":true,\"duration\":478,\"testMatch\":\"tests/simple.js\"}"
}
```

Failed response:
```json
{
  "statusCode": 500,
  "body": "{\"error\":\"Error message\",\"success\":false}"
}
```

---

## Troubleshooting

### Lambda function not found
- Ensure deployment was successful: `serverless deploy`
- Check function name matches: `playwright-serverless-dev-run-tests`

### Tests not running
- Verify test file path in payload matches actual file location
- Check test file exports a function correctly
- Review CloudWatch logs for Lambda function

### Authentication errors
- Verify AWS credentials: `aws configure list`
- Check IAM permissions for Lambda invoke

---

## Quick Reference

| Method | Use Case | Command |
|--------|----------|---------|
| **One-Line Script** | **Quick test run** | **`.\run-tests-simple.ps1`** |
| Serverless Runner | Run all tests with batching | `cd serverless-runner && npm start` |
| AWS CLI (single) | Test one specific file | `aws lambda invoke ...` |
| AWS CLI (multiple) | Run specific set of tests | PowerShell loop script |
| HTTP Endpoint | Integration testing | `curl` or `Invoke-RestMethod` |

---

## Next Steps

- Customize test patterns in `serverless-runner/index.js`
- Add more test files to the `tests/` directory
- Configure batch size and delays for concurrent execution
- Set up CI/CD pipeline using these methods

