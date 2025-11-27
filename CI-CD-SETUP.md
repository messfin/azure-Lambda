# CI/CD Pipeline Setup Guide

This guide explains how to set up CI/CD pipelines for running Playwright tests on AWS Lambda.

## 📋 Overview

The CI/CD pipelines will:
1. **Deploy** the Lambda function to AWS
2. **Run** all tests on the deployed Lambda function
3. **Report** test results and artifacts

---

## 🚀 Platform-Specific Setup

### GitHub Actions

#### Prerequisites
- GitHub repository
- AWS credentials (Access Key ID and Secret Access Key)

#### Setup Steps

1. **Add AWS Secrets to GitHub**
   - Go to your repository → Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`: Your AWS access key
     - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

2. **Enable the Workflow**
   - The workflow file is already created at `.github/workflows/lambda-tests.yml`
   - Push to `main` or `develop` branch to trigger
   - Or manually trigger via Actions tab → "Lambda Playwright Tests" → "Run workflow"

3. **Workflow Features**
   - ✅ Automatic deployment on push/PR
   - ✅ Runs all tests sequentially
   - ✅ Uploads test results as artifacts
   - ✅ Optional: Run via serverless-runner (disabled by default)

#### Configuration

Edit `.github/workflows/lambda-tests.yml` to:
- Change `AWS_REGION` if needed
- Modify test files list
- Enable `test-with-runner` job if desired

---

### Azure DevOps

#### Prerequisites
- Azure DevOps project
- AWS Service Connection configured

#### Setup Steps

1. **Create AWS Service Connection**
   - Go to Project Settings → Service connections
   - Click "New service connection" → "AWS"
   - Enter:
     - **Connection name**: `AWS Service Connection`
     - **Authentication method**: AWS Credentials
     - **Access Key ID**: Your AWS access key
     - **Secret Access Key**: Your AWS secret key
     - **Region**: `us-east-1` (or your region)

2. **Create Pipeline**
   - Go to Pipelines → New pipeline
   - Select your repository
   - Choose "Existing Azure Pipelines YAML file"
   - Select `azure-pipelines-lambda.yml`
   - Save and run

3. **Pipeline Features**
   - ✅ Deploys Lambda function
   - ✅ Runs all tests on Lambda
   - ✅ Publishes test results and artifacts
   - ✅ Optional: Run via serverless-runner

#### Configuration

Edit `azure-pipelines-lambda.yml` to:
- Change `AWS_REGION` variable
- Modify test files list
- Enable `TestWithRunner` stage if desired

---

### GitLab CI/CD

#### Prerequisites
- GitLab repository
- AWS credentials configured as CI/CD variables

#### Setup Steps

1. **Add AWS Variables to GitLab**
   - Go to Settings → CI/CD → Variables
   - Add the following variables:
     - `AWS_ACCESS_KEY_ID`: Your AWS access key (masked)
     - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key (masked, protected)
     - `AWS_DEFAULT_REGION`: `us-east-1` (or your region)

2. **Enable the Pipeline**
   - The pipeline file is already created at `.gitlab-ci.yml`
   - Push to `main` or `develop` branch to trigger
   - Or manually trigger via CI/CD → Pipelines → Run pipeline

3. **Pipeline Features**
   - ✅ Automatic deployment
   - ✅ Runs all tests on Lambda
   - ✅ Saves test artifacts
   - ✅ Optional: Manual trigger for serverless-runner

#### Configuration

Edit `.gitlab-ci.yml` to:
- Change `AWS_REGION` variable
- Modify test files list
- Change `test_with_runner.when` from `manual` to `on_success` to run automatically

---

## 🔧 Common Configuration

### Environment Variables

All pipelines use these variables (adjust as needed):

```yaml
AWS_REGION: us-east-1
LAMBDA_FUNCTION_NAME: playwright-serverless-dev-run-tests
NODE_VERSION: 18.x
```

### Cross-Platform Test Runner Scripts

For maximum compatibility, use the provided test runner scripts:

**Linux/Mac/Unix:**
```bash
chmod +x ci-run-tests.sh
./ci-run-tests.sh
```

**Windows (PowerShell):**
```powershell
.\ci-run-tests.ps1
```

**With custom parameters:**
```bash
LAMBDA_FUNCTION_NAME=my-function AWS_REGION=us-west-2 ./ci-run-tests.sh
```

```powershell
.\ci-run-tests.ps1 -LambdaFunctionName "my-function" -AwsRegion "us-west-2"
```

These scripts can be used in any CI/CD platform and handle:
- ✅ AWS CLI detection and installation
- ✅ Error handling and reporting
- ✅ Color-coded output
- ✅ Exit codes for CI/CD integration
- ✅ Test result summaries

### Test Files

The pipelines run these tests by default:
- `tests/simple.js`
- `tests/demo.lambda.js`
- `tests/example.lambda.js`
- `tests/api.lambda.js`
- `tests/apiChallenge.lambda.js`
- `tests/demo-todo-app.lambda.js`
- `tests/api-gravity.lambda.js`

To modify, edit the test array in each pipeline file.

---

## 📊 Pipeline Stages

### Stage 1: Deploy
- Installs Node.js and dependencies
- Installs Serverless Framework
- Configures AWS credentials
- Deploys Lambda function using `serverless deploy`

### Stage 2: Test
- Configures AWS credentials
- Installs AWS CLI (if needed)
- Creates test runner script
- Invokes Lambda for each test file
- Parses and reports results
- Uploads artifacts

### Stage 3: Test with Runner (Optional)
- Uses serverless-runner for batch processing
- Runs tests concurrently in batches
- Provides detailed logging

---

## 🔐 Security Best Practices

1. **Never commit credentials**
   - Use secrets/variables in CI/CD platform
   - Rotate credentials regularly

2. **Use IAM roles when possible**
   - GitHub Actions: Use OIDC
   - Azure DevOps: Use service connections
   - GitLab: Use CI/CD variables

3. **Limit permissions**
   - Create IAM user with minimal required permissions:
     - Lambda deploy permissions
     - Lambda invoke permissions
     - ECR push permissions (for Docker images)

4. **Protect secrets**
   - Mark sensitive variables as "protected" and "masked"
   - Use different credentials for different environments

---

## 🐛 Troubleshooting

### Deployment Fails

**Error: 403 Forbidden (ECR)**
- Ensure IAM user has ECR permissions
- Attach `AmazonEC2ContainerRegistryPowerUser` policy

**Error: Lambda function not found**
- Check function name matches in pipeline variables
- Verify deployment stage completed successfully

### Tests Fail

**Error: Lambda invocation failed**
- Check AWS credentials are configured correctly
- Verify Lambda function exists and is deployed
- Check CloudWatch logs for Lambda errors

**Error: Test timeout**
- Increase Lambda timeout in `serverless.yml`
- Check test complexity and network latency

### Pipeline-Specific Issues

**GitHub Actions:**
- Check Actions tab for detailed logs
- Verify secrets are set correctly

**Azure DevOps:**
- Check pipeline logs
- Verify service connection is working
- Ensure agent has internet access

**GitLab:**
- Check CI/CD → Pipelines → Job logs
- Verify variables are set and not expired
- Check runner has AWS CLI access

---

## 📈 Monitoring

### View Test Results

- **GitHub Actions**: Actions tab → Workflow run → Artifacts
- **Azure DevOps**: Pipelines → Run → Artifacts
- **GitLab**: CI/CD → Pipelines → Job → Artifacts

### CloudWatch Logs

Monitor Lambda execution:
- AWS Console → CloudWatch → Log groups
- Look for `/aws/lambda/playwright-serverless-dev-run-tests`

### Metrics

Track:
- Test execution time
- Success/failure rates
- Lambda invocation counts
- Error rates

---

## 🚀 Advanced Configuration

### Parallel Test Execution

Modify the test runner script to run tests in parallel:

```bash
# Run tests in background
for test in "${tests[@]}"; do
  run_test "$test" &
done
wait  # Wait for all to complete
```

### Custom Test Patterns

Use environment variables to specify test patterns:

```yaml
variables:
  TEST_PATTERN: "tests/api*.lambda.js"
```

### Conditional Deployment

Only deploy on specific branches:

```yaml
only:
  - main
  - production
```

### Scheduled Runs

Add scheduled triggers (GitHub Actions example):

```yaml
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
```

---

## 📝 Example: Complete Workflow

1. Developer pushes code to `develop` branch
2. CI/CD pipeline triggers automatically
3. Pipeline deploys Lambda function
4. Pipeline runs all tests on Lambda
5. Test results are published as artifacts
6. If tests pass, code can be merged to `main`
7. Production deployment triggers on `main` branch

---

## 🔗 Related Documentation

- [How to Run Tests Locally](./HOW-TO-RUN-TESTS.md)
- [Serverless Framework Docs](https://www.serverless.com/framework/docs)
- [AWS Lambda Docs](https://docs.aws.amazon.com/lambda/)

---

## 💡 Tips

1. **Start with manual triggers** to test pipeline before enabling automatic runs
2. **Use separate AWS accounts** for dev/staging/production
3. **Monitor costs** - Lambda invocations and ECR storage
4. **Set up alerts** for failed deployments or tests
5. **Keep pipeline files in version control** for easy rollback

