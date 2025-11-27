# Lambda Playwright Test Infrastructure

## Overview

This document describes the complete AWS Lambda-based Playwright test infrastructure that enables running browser tests in a serverless environment.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Test Execution Flow                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Local/CI → AWS Lambda → Chromium → Test Execution → Results│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Components

1. **Lambda Function**: `playwright-serverless-dev-run-tests`

   - Runtime: Node.js 18 (Docker container)
   - Region: us-east-1
   - Timeout: 60 seconds
   - Memory: Default (128 MB - can be increased if needed)

2. **Docker Image**: Custom image with Playwright + Chromium

   - Base: `public.ecr.aws/lambda/nodejs:18`
   - Includes: Chromium browser, system dependencies, test files

3. **Test Files**: Converted to async function exports
   - Format: `module.exports = async (page) => { ... }`
   - Location: `/tests/*.lambda.js`

## Test Conversion

### Original Format (Playwright Test)

```javascript
import { test, expect } from "@playwright/test";

test("has title", async ({ page }) => {
  await page.goto("https://playwright.dev/");
  await expect(page).toHaveTitle(/Playwright/);
});
```

### Converted Format (Lambda Compatible)

```javascript
const { expect } = require("@playwright/test");

module.exports = async (page) => {
  console.log("Running test: has title");
  await page.goto("https://playwright.dev/");
  await expect(page).toHaveTitle(/Playwright/);
};
```

## Test Files

All tests have been converted to the Lambda-compatible format:

| Test File                       | Description               | Status               |
| ------------------------------- | ------------------------- | -------------------- |
| `tests/simple.js`               | Basic verification test   | ✅ Passing (436ms)   |
| `tests/demo.lambda.js`          | Sauce Demo login test     | ✅ Passing (2,245ms) |
| `tests/example.lambda.js`       | Playwright.dev navigation | ✅ Passing (3,078ms) |
| `tests/api.lambda.js`           | API testing               | ✅ Passing (831ms)   |
| `tests/apiChallenge.lambda.js`  | Product API test          | ✅ Passing (567ms)   |
| `tests/demo-todo-app.lambda.js` | TodoMVC app tests         | ✅ Passing (1,283ms) |
| `tests/api-gravity.lambda.js`   | API tests with baseURL    | ✅ Passing (650ms)   |

**Total: 7/7 tests passing** ✅

## Infrastructure Files

### 1. Dockerfile

```dockerfile
FROM public.ecr.aws/lambda/nodejs:18

# Install system dependencies for Chromium
RUN yum install -y \
    nss nspr atk at-spi2-atk cups-libs libdrm \
    libxkbcommon libxcomposite libxdamage libxrandr \
    libxfixes mesa-libgbm alsa-lib gtk3 libXScrnSaver \
    && yum clean all

# Install Node.js dependencies
COPY package*.json ./
RUN npm ci

# Set Playwright browsers path
ENV PLAYWRIGHT_BROWSERS_PATH=/var/task/browsers

# Install Playwright browsers
RUN npx playwright install chromium

# Copy Lambda handler and tests
COPY lambda/ ${LAMBDA_TASK_ROOT}/
COPY tests/ ${LAMBDA_TASK_ROOT}/tests/

CMD [ "handler.runTest" ]
```

### 2. Lambda Handler (`lambda/handler.js`)

```javascript
const { chromium } = require("@playwright/test");
const path = require("path");

module.exports.runTest = async (event) => {
  let browser = null;
  try {
    const { testMatch } = event.body;
    if (!testMatch) {
      return {
        statusCode: 400,
        body: JSON.stringify("Property 'testMatch' not found."),
      };
    }

    // Launch Chromium browser
    browser = await chromium.launch({
      headless: true,
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--single-process",
      ],
    });

    const context = await browser.newContext();
    const page = await context.newPage();

    // Load and execute test
    const testFilePath = path.resolve(__dirname, testMatch);
    const testFn = require(testFilePath);

    if (typeof testFn !== "function") {
      throw new Error(`Test file ${testMatch} does not export a function.`);
    }

    const startTime = Date.now();
    await testFn(page);
    const duration = Date.now() - startTime;

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        duration,
        testMatch,
      }),
    };
  } catch (error) {
    console.error("Test execution failed:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        success: false,
        error: error.message,
        stack: error.stack,
      }),
    };
  } finally {
    if (browser) {
      await browser.close();
    }
  }
};
```

### 3. Serverless Configuration (`serverless.yml`)

```yaml
service: playwright-serverless

frameworkVersion: "3"

provider:
  name: aws
  runtime: nodejs18.x
  stage: dev
  region: us-east-1
  ecr:
    images:
      baseimage:
        path: ./
        file: Dockerfile
        platform: linux/amd64

functions:
  run-tests:
    timeout: 60
    image: baseimage
    events:
      - http:
          path: /
          method: post
          integration: lambda-proxy
```

## Running Tests

### Local Execution (PowerShell)

```powershell
.\ci-run-tests.ps1
```

**Output:**

```
🚀 Starting Lambda Playwright Tests
Function: playwright-serverless-dev-run-tests
Region: us-east-1
Total tests: 7

🧪 Running: tests/simple.js
✅ Passed - Duration: 436ms

🧪 Running: tests/demo.lambda.js
✅ Passed - Duration: 2245ms

... (all tests)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Test Summary
Total:   7
Passed:  7
Failed:  0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ All tests passed!
```

### Local Execution (Bash)

```bash
chmod +x run-lambda-tests.sh
./run-lambda-tests.sh
```

### Manual Lambda Invocation

```powershell
# Create payload
$payload = @{
    body = @{
        testMatch = "tests/simple.js"
    }
} | ConvertTo-Json

$payload | Out-File test-payload.json

# Invoke Lambda
aws lambda invoke `
  --function-name playwright-serverless-dev-run-tests `
  --cli-binary-format raw-in-base64-out `
  --payload file://test-payload.json `
  --region us-east-1 `
  response.json

# View results
Get-Content response.json | ConvertFrom-Json
```

### GitHub Actions (CI/CD)

The workflow automatically runs on:

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual trigger via `workflow_dispatch`

**Workflow URL**: [https://github.com/messfin/azure-Lambda/actions](https://github.com/messfin/azure-Lambda/actions)

## Deployment

### Prerequisites

1. AWS CLI installed and configured
2. Docker installed and running
3. Serverless Framework installed: `npm install -g serverless`
4. AWS credentials with Lambda and ECR permissions

### Deploy to AWS Lambda

```powershell
# Set environment variable to avoid Docker attestation issues
$env:BUILDX_NO_DEFAULT_ATTESTATIONS=1

# Deploy
serverless deploy
```

**Deployment time**: ~10-15 minutes (includes Docker image build and upload)

### Verify Deployment

```powershell
aws lambda get-function --function-name playwright-serverless-dev-run-tests
```

## GitHub Actions Workflow

### Configuration (`.github/workflows/lambda-tests.yml`)

**Jobs:**

1. **deploy**: Builds and deploys Lambda function
2. **test**: Runs all 7 tests on Lambda
3. **test-with-runner**: (Optional) Uses serverless-runner for batch execution

**Required Secrets:**

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Workflow Triggers

- Push to main/develop
- Pull requests
- Manual dispatch

## Test Results

### Latest Run (Local)

```
Date: 2025-11-27
Environment: Local (PowerShell)
Total Tests: 7
Passed: 7
Failed: 0
Success Rate: 100%
```

### Performance Metrics

| Test                    | Duration    |
| ----------------------- | ----------- |
| simple.js               | 436ms       |
| demo.lambda.js          | 2,245ms     |
| example.lambda.js       | 3,078ms     |
| api.lambda.js           | 831ms       |
| apiChallenge.lambda.js  | 567ms       |
| demo-todo-app.lambda.js | 1,283ms     |
| api-gravity.lambda.js   | 650ms       |
| **Average**             | **1,156ms** |

## Troubleshooting

### Common Issues

#### 1. Browser Not Found

**Error**: `Executable doesn't exist at /home/sbx_user1051/.cache/ms-playwright/...`

**Solution**: Ensure `PLAYWRIGHT_BROWSERS_PATH` is set in Dockerfile and browsers are installed:

```dockerfile
ENV PLAYWRIGHT_BROWSERS_PATH=/var/task/browsers
RUN npx playwright install chromium
```

#### 2. Missing System Dependencies

**Error**: `Host system is missing dependencies to run browsers`

**Solution**: Install all required system libraries in Dockerfile (already included).

#### 3. Docker Attestation Error

**Error**: `The image manifest, config or layer media type... is not supported`

**Solution**: Set environment variable before deployment:

```powershell
$env:BUILDX_NO_DEFAULT_ATTESTATIONS=1
```

#### 4. Lambda Timeout

**Error**: Task timed out after 60 seconds

**Solution**: Increase timeout in `serverless.yml`:

```yaml
functions:
  run-tests:
    timeout: 120 # Increase to 120 seconds
```

## Cost Estimation

### AWS Lambda Pricing (us-east-1)

- **Compute**: $0.0000166667 per GB-second
- **Requests**: $0.20 per 1M requests

### Example Monthly Cost (1000 test runs)

- Duration: ~10 seconds average per test
- Memory: 512 MB
- Requests: 7,000 (7 tests × 1000 runs)

**Estimated Cost**: ~$0.15/month

## Best Practices

1. **Test Isolation**: Each test runs in a fresh browser context
2. **Error Handling**: All tests include try-catch with detailed error reporting
3. **Logging**: Console logs are captured in CloudWatch
4. **Timeouts**: Set appropriate timeouts for long-running tests
5. **Parallel Execution**: Use serverless-runner for batch processing

## Future Enhancements

- [ ] Add support for Firefox and WebKit browsers
- [ ] Implement test result aggregation and reporting
- [ ] Add screenshot capture on test failure
- [ ] Integrate with test reporting tools (Allure, etc.)
- [ ] Add support for test data fixtures
- [ ] Implement test retry logic
- [ ] Add performance monitoring and metrics

## Resources

- **Repository**: [https://github.com/messfin/azure-Lambda](https://github.com/messfin/azure-Lambda)
- **Playwright Docs**: [https://playwright.dev](https://playwright.dev)
- **AWS Lambda Docs**: [https://docs.aws.amazon.com/lambda](https://docs.aws.amazon.com/lambda)
- **Serverless Framework**: [https://www.serverless.com](https://www.serverless.com)

## Support

For issues or questions:

1. Check CloudWatch logs: `aws logs tail /aws/lambda/playwright-serverless-dev-run-tests --follow`
2. Review test results in GitHub Actions artifacts
3. Run tests locally for debugging: `.\ci-run-tests.ps1`

---

**Last Updated**: 2025-11-27  
**Status**: ✅ All systems operational  
**Test Success Rate**: 100% (7/7 passing)
