# Setup Scripts for New Projects

These scripts allow you to bootstrap the AWS Lambda + Playwright infrastructure into any existing project that already has Playwright tests.

---

## 📋 Prerequisites

Before running the setup script, ensure you have:

1. **Existing Playwright tests** in your project
2. **Node.js** installed (v16 or higher)
3. **npm** installed
4. **AWS CLI** configured (for deployment)
5. **Docker** installed (optional, for Docker-based execution)

---

## 🚀 Quick Start

### For Windows (PowerShell)

```powershell
# Download the script
curl -O https://raw.githubusercontent.com/YOUR_REPO/setup-aws-lambda-tests.ps1

# Run the script
.\setup-aws-lambda-tests.ps1
```

### For Linux/Mac (Bash)

```bash
# Download the script
curl -O https://raw.githubusercontent.com/YOUR_REPO/setup-aws-lambda-tests.sh

# Make it executable
chmod +x setup-aws-lambda-tests.sh

# Run the script
./setup-aws-lambda-tests.sh
```

---

## 📖 Usage

### PowerShell (Windows)

```powershell
# Basic usage (uses defaults)
.\setup-aws-lambda-tests.ps1

# Custom test directory and pattern
.\setup-aws-lambda-tests.ps1 -TestDirectory "e2e" -TestPattern "**/*.test.ts"

# Skip AWS deployment (just setup files)
.\setup-aws-lambda-tests.ps1 -SkipAWSDeploy

# Custom AWS region
.\setup-aws-lambda-tests.ps1 -AWSRegion "us-west-2"

# All options combined
.\setup-aws-lambda-tests.ps1 `
    -TestDirectory "e2e" `
    -TestPattern "**/*.test.ts" `
    -AWSRegion "eu-west-1" `
    -SkipAWSDeploy
```

### Bash (Linux/Mac)

```bash
# Basic usage (uses defaults)
./setup-aws-lambda-tests.sh

# Custom test directory and pattern
./setup-aws-lambda-tests.sh --test-directory e2e --test-pattern '**/*.test.ts'

# Skip AWS deployment (just setup files)
./setup-aws-lambda-tests.sh --skip-aws-deploy

# Custom AWS region
./setup-aws-lambda-tests.sh --aws-region us-west-2

# All options combined
./setup-aws-lambda-tests.sh \
    --test-directory e2e \
    --test-pattern '**/*.test.ts' \
    --aws-region eu-west-1 \
    --skip-aws-deploy

# Show help
./setup-aws-lambda-tests.sh --help
```

---

## ⚙️ Parameters

| Parameter       | PowerShell       | Bash                | Default        | Description                     |
| --------------- | ---------------- | ------------------- | -------------- | ------------------------------- |
| Test Directory  | `-TestDirectory` | `--test-directory`  | `tests`        | Directory containing test files |
| Test Pattern    | `-TestPattern`   | `--test-pattern`    | `**/*.spec.js` | Glob pattern for test files     |
| Skip AWS Deploy | `-SkipAWSDeploy` | `--skip-aws-deploy` | `false`        | Skip AWS Lambda deployment      |
| AWS Region      | `-AWSRegion`     | `--aws-region`      | `us-east-1`    | AWS region for Lambda           |

---

## 📁 What Gets Created

The script creates the following structure:

```
your-project/
├── serverless-runner/           # Test orchestrator (runs locally)
│   ├── package.json            # Dependencies
│   ├── index.js                # Main orchestrator
│   └── helpers/
│       ├── logger.js           # Logging utilities
│       ├── requester.js        # Lambda invocation
│       └── utils.js            # Helper functions
├── lambda/                      # Lambda function code
│   └── index.js                # Lambda handler
├── serverless.yml              # Serverless Framework config
├── Makefile                    # Build and test commands
├── run-tests-with-output.ps1   # PowerShell helper (Windows)
├── run-tests-with-output.sh    # Bash helper (Linux/Mac)
└── .gitignore                  # Updated with new entries
```

---

## 🔧 Post-Setup Steps

After running the setup script:

### 1. Configure AWS Credentials

```bash
aws configure
```

### 2. Install Serverless Framework (if not installed)

```bash
npm install -g serverless
```

### 3. Customize Lambda Handler

Edit `lambda/index.js` to match your test structure. The default handler assumes tests export a function, but you may need to adapt it for your specific test framework.

**Example for Playwright Test Runner:**

```javascript
// lambda/index.js
const { chromium } = require("playwright-core");
const { test } = require("@playwright/test");

exports.handler = async (event) => {
  // Your custom test execution logic
};
```

### 4. Deploy to AWS Lambda

```bash
serverless deploy --verbose
```

Or using Make:

```bash
make deploy
```

### 5. Run Tests

**Option 1: Docker + AWS Lambda (Recommended for CI/CD)**

```bash
make test-serverless
```

**Option 2: Local + AWS Lambda (Fastest for development)**

```bash
cd serverless-runner
npm start
```

**Option 3: With output logging**

```powershell
# Windows
.\run-tests-with-output.ps1

# Linux/Mac
./run-tests-with-output.sh
```

---

## 🎯 Example Scenarios

### Scenario 1: TypeScript Project with Tests in `e2e/`

```powershell
# Windows
.\setup-aws-lambda-tests.ps1 -TestDirectory "e2e" -TestPattern "**/*.test.ts"

# Linux/Mac
./setup-aws-lambda-tests.sh --test-directory e2e --test-pattern '**/*.test.ts'
```

### Scenario 2: Setup Files Only (Deploy Later)

```powershell
# Windows
.\setup-aws-lambda-tests.ps1 -SkipAWSDeploy

# Linux/Mac
./setup-aws-lambda-tests.sh --skip-aws-deploy
```

### Scenario 3: EU Region Deployment

```powershell
# Windows
.\setup-aws-lambda-tests.ps1 -AWSRegion "eu-west-1"

# Linux/Mac
./setup-aws-lambda-tests.sh --aws-region eu-west-1
```

### Scenario 4: Monorepo with Tests in `packages/e2e/tests/`

```powershell
# Windows
.\setup-aws-lambda-tests.ps1 -TestDirectory "packages/e2e/tests"

# Linux/Mac
./setup-aws-lambda-tests.sh --test-directory packages/e2e/tests
```

---

## 🔍 What the Script Does

1. ✅ **Verifies prerequisites** (Node.js, npm, Docker, AWS CLI)
2. ✅ **Checks for existing tests** in your project
3. ✅ **Creates serverless-runner** directory with orchestrator code
4. ✅ **Creates Lambda handler** template
5. ✅ **Generates serverless.yml** with AWS configuration
6. ✅ **Creates Makefile** with convenient commands
7. ✅ **Generates helper scripts** for running tests
8. ✅ **Updates .gitignore** with new entries
9. ✅ **Installs dependencies** for serverless-runner
10. ✅ **Backs up existing files** if they already exist

---

## ⚠️ Important Notes

### Lambda Handler Customization

The generated `lambda/index.js` is a **template** that assumes:

- Tests export a function
- Tests accept a `page` object

**You MUST customize it** based on your test structure:

- **Playwright Test Runner**: Use `@playwright/test` API
- **Jest + Playwright**: Adapt for Jest test structure
- **Custom framework**: Implement your own test execution logic

### Test Pattern

The test pattern uses glob syntax:

- `**/*.spec.js` - All `.spec.js` files recursively
- `**/*.test.ts` - All `.test.ts` files recursively
- `e2e/**/*.test.js` - Only in `e2e` directory
- `tests/integration/*.spec.js` - Specific directory

### AWS Costs

Running tests on AWS Lambda incurs costs:

- **Free tier**: 1M requests/month, 400,000 GB-seconds
- **Typical cost**: $0.50-$2.00/month for moderate usage
- **Monitor usage**: Use AWS Cost Explorer

---

## 🐛 Troubleshooting

### Script fails with "Test directory not found"

**Solution**: Specify the correct test directory:

```bash
./setup-aws-lambda-tests.sh --test-directory path/to/tests
```

### "Node.js not found" error

**Solution**: Install Node.js from [nodejs.org](https://nodejs.org/)

### "Serverless Framework not found" warning

**Solution**: Install globally:

```bash
npm install -g serverless
```

### Existing files backed up

If the script finds existing `serverless-runner` directory, it creates a backup:

```
serverless-runner.backup.20251126_093616
```

You can safely delete backups after verifying the new setup works.

---

## 📚 Next Steps

After setup:

1. Read [QUICK-START.md](./QUICK-START.md) for quick commands
2. Review [TESTING-TYPES.md](./TESTING-TYPES.md) to understand execution types
3. Follow [SETUP-GUIDE.md](./SETUP-GUIDE.md) for detailed configuration
4. Check [ARCHITECTURE.md](./ARCHITECTURE.md) to understand the system
5. Use [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) if you encounter issues

---

## 🤝 Contributing

Found an issue with the setup script? Please:

1. Check existing issues
2. Create a new issue with details
3. Include your OS, Node version, and error message

---

## 📄 License

These setup scripts are part of the running-playwright-on-aws-lambda project.
See [LICENSE](./LICENSE) for details.

---

## 🔗 Resources

- [Serverless Framework Docs](https://www.serverless.com/framework/docs)
- [AWS Lambda Docs](https://docs.aws.amazon.com/lambda/)
- [Playwright Docs](https://playwright.dev/)
- [Original Project](https://github.com/PauloGoncalvesBH/running-playwright-on-aws-lambda)
