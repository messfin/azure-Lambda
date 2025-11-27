# Quick Setup Guide for D:\Azure-test

This guide will help you set up AWS Lambda + Playwright infrastructure for your Azure-test project.

---

## 📋 What You Have

The following files have been copied to your project:

- ✅ `setup-aws-lambda-tests.ps1` - PowerShell setup script
- ✅ `setup-aws-lambda-tests.sh` - Bash setup script (for WSL/Linux)
- ✅ `SETUP-SCRIPTS-README.md` - Detailed documentation

---

## 🚀 Quick Start

### Step 1: Open PowerShell in Your Project Directory

```powershell
cd D:\Azure-test
```

### Step 2: Run the Setup Script

Since your tests are in the `tests` directory, run:

```powershell
.\setup-aws-lambda-tests.ps1 -TestDirectory "tests"
```

**Or with custom test pattern (if your tests use different naming):**

```powershell
# For .test.js files
.\setup-aws-lambda-tests.ps1 -TestDirectory "tests" -TestPattern "**/*.test.js"

# For .spec.ts files
.\setup-aws-lambda-tests.ps1 -TestDirectory "tests" -TestPattern "**/*.spec.ts"

# For all test files
.\setup-aws-lambda-tests.ps1 -TestDirectory "tests" -TestPattern "**/*{.spec,.test}.{js,ts}"
```

### Step 3: Follow the Script Output

The script will:

1. ✅ Check prerequisites (Node.js, npm, Docker, AWS CLI)
2. ✅ Verify your test directory exists
3. ✅ Create serverless-runner directory
4. ✅ Generate Lambda handler
5. ✅ Create configuration files
6. ✅ Install dependencies
7. ✅ Show next steps

---

## 📝 What Gets Created

After running the script, your project will have:

```
D:\Azure-test/
├── tests/                       # Your existing tests (unchanged)
├── serverless-runner/           # NEW - Test orchestrator
│   ├── package.json
│   ├── index.js
│   └── helpers/
├── lambda/                      # NEW - Lambda function
│   └── index.js
├── serverless.yml              # NEW - AWS configuration
├── Makefile                    # NEW - Build commands
├── run-tests-with-output.ps1   # NEW - Helper script
└── .gitignore                  # UPDATED
```

---

## ⚙️ Post-Setup Steps

After the script completes:

### 1. Configure AWS Credentials (if not already done)

```powershell
aws configure
```

### 2. Install Serverless Framework (if not installed)

```powershell
npm install -g serverless
```

### 3. Customize Lambda Handler

Edit `lambda/index.js` to match your test structure. The default template may need adjustments based on how your tests are written.

### 4. Deploy to AWS Lambda

```powershell
serverless deploy --verbose
```

Or:

```powershell
make deploy
```

### 5. Run Your Tests!

**Option 1: Docker + AWS Lambda (Recommended)**

```powershell
make test-serverless
```

**Option 2: Local + AWS Lambda (Faster startup)**

```powershell
cd serverless-runner
npm start
```

**Option 3: With output logging**

```powershell
.\run-tests-with-output.ps1
```

---

## 🎯 Expected Results

After setup and deployment, you should see:

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ✅ Setup Complete!                                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

📁 Files Created:
  ├─ serverless-runner/          (Test orchestrator)
  ├─ lambda/                     (Lambda function)
  ├─ serverless.yml              (AWS configuration)
  ├─ Makefile                    (Build commands)
  └─ run-tests-with-output.ps1   (Helper script)

🚀 Next Steps:
1️⃣  Configure AWS credentials
2️⃣  Install Serverless Framework
3️⃣  Customize lambda/index.js
4️⃣  Deploy to AWS Lambda
5️⃣  Run tests
```

---

## 🔧 Common Scenarios

### If you get "Execution Policy" error:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then run the script again.

### If you want to skip AWS deployment for now:

```powershell
.\setup-aws-lambda-tests.ps1 -TestDirectory "tests" -SkipAWSDeploy
```

### If you want to use a different AWS region:

```powershell
.\setup-aws-lambda-tests.ps1 -TestDirectory "tests" -AWSRegion "us-west-2"
```

---

## 📚 Additional Documentation

For more details, see:

- `SETUP-SCRIPTS-README.md` - Full documentation
- Original project docs at: `D:\running-playwright-on-aws-lambda\`

---

## 🆘 Need Help?

If you encounter issues:

1. Check the script output for error messages
2. Verify prerequisites are installed
3. Review `SETUP-SCRIPTS-README.md`
4. Check the troubleshooting section

---

## 🎉 Ready to Go!

You're all set! Just run:

```powershell
cd D:\Azure-test
.\setup-aws-lambda-tests.ps1 -TestDirectory "tests"
```

And follow the prompts!
