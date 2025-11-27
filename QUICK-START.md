# Quick Start Guide - Lambda Playwright Tests

## 🚀 Run Tests Locally

```powershell
.\ci-run-tests.ps1
```

**Expected Output**: All 7 tests passing ✅

## 📋 Test Files

All tests export a single async function:

```javascript
const { expect } = require("@playwright/test");

module.exports = async (page) => {
  // Your test code here
  await page.goto("https://example.com");
  await expect(page).toHaveTitle(/Example/);
};
```

## 🔧 Deploy to AWS Lambda

```powershell
# Set environment variable
$env:BUILDX_NO_DEFAULT_ATTESTATIONS=1

# Deploy
serverless deploy
```

## 🧪 Run Single Test

```powershell
# Create payload
@{body=@{testMatch="tests/simple.js"}} | ConvertTo-Json | Out-File test-payload.json

# Invoke Lambda
aws lambda invoke `
  --function-name playwright-serverless-dev-run-tests `
  --cli-binary-format raw-in-base64-out `
  --payload file://test-payload.json `
  response.json

# View result
Get-Content response.json | ConvertFrom-Json
```

## 📊 Current Status

✅ **7/7 tests passing**

| Test                    | Duration |
| ----------------------- | -------- |
| simple.js               | 436ms    |
| demo.lambda.js          | 2,245ms  |
| example.lambda.js       | 3,078ms  |
| api.lambda.js           | 831ms    |
| apiChallenge.lambda.js  | 567ms    |
| demo-todo-app.lambda.js | 1,283ms  |
| api-gravity.lambda.js   | 650ms    |

## 🔗 Links

- **Repository**: [https://github.com/messfin/azure-Lambda](https://github.com/messfin/azure-Lambda)
- **GitHub Actions**: [https://github.com/messfin/azure-Lambda/actions](https://github.com/messfin/azure-Lambda/actions)
- **Full Documentation**: See `LAMBDA-TEST-INFRASTRUCTURE.md`

## 💡 Common Commands

```powershell
# Run all tests
.\ci-run-tests.ps1

# Deploy to Lambda
serverless deploy

# View Lambda logs
aws logs tail /aws/lambda/playwright-serverless-dev-run-tests --follow

# Check deployment status
aws lambda get-function --function-name playwright-serverless-dev-run-tests
```

## ⚙️ GitHub Actions

Push to `main` branch to trigger automatic deployment and testing:

```powershell
git add .
git commit -m "Update tests"
git push origin main
```

## 🐛 Troubleshooting

**Issue**: Tests fail locally  
**Solution**: Check AWS credentials are configured

**Issue**: Deployment fails  
**Solution**: Ensure Docker is running and `BUILDX_NO_DEFAULT_ATTESTATIONS=1` is set

**Issue**: Lambda timeout  
**Solution**: Increase timeout in `serverless.yml` (currently 60s)

---

For detailed information, see `LAMBDA-TEST-INFRASTRUCTURE.md`
