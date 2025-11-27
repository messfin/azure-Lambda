#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Bootstrap AWS Lambda + Playwright infrastructure into an existing project

.DESCRIPTION
    This script sets up the serverless test infrastructure for running Playwright tests
    on AWS Lambda. It assumes you already have Playwright tests in your project.

.PARAMETER TestDirectory
    Directory containing your test files (default: "tests")

.PARAMETER TestPattern
    Glob pattern for test files (default: "**/*.spec.js")

.PARAMETER SkipAWSDeploy
    Skip AWS Lambda deployment (just setup files)

.PARAMETER AWSRegion
    AWS region for Lambda deployment (default: "us-east-1")

.EXAMPLE
    .\setup-aws-lambda-tests.ps1
    
.EXAMPLE
    .\setup-aws-lambda-tests.ps1 -TestDirectory "e2e" -TestPattern "**/*.test.ts"
    
.EXAMPLE
    .\setup-aws-lambda-tests.ps1 -SkipAWSDeploy
#>

param(
    [string]$TestDirectory = "tests",
    [string]$TestPattern = "**/*.spec.js",
    [switch]$SkipAWSDeploy,
    [string]$AWSRegion = "us-east-1"
)

# Color output functions
function Write-Success { Write-Host "✅ $args" -ForegroundColor Green }
function Write-Info { Write-Host "ℹ️  $args" -ForegroundColor Cyan }
function Write-Warning { Write-Host "⚠️  $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "❌ $args" -ForegroundColor Red }
function Write-Step { Write-Host "`n🔹 $args" -ForegroundColor Blue }

Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   AWS Lambda + Playwright Test Infrastructure Setup          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

# Step 1: Verify prerequisites
Write-Step "Checking prerequisites..."

# Check if test directory exists
if (-not (Test-Path $TestDirectory)) {
    Write-Error "Test directory '$TestDirectory' not found!"
    Write-Info "Please specify the correct test directory with -TestDirectory parameter"
    exit 1
}
Write-Success "Test directory found: $TestDirectory"

# Check for test files
$testFiles = Get-ChildItem -Path $TestDirectory -Filter "*.spec.js" -Recurse -ErrorAction SilentlyContinue
if ($testFiles.Count -eq 0) {
    $testFiles = Get-ChildItem -Path $TestDirectory -Filter "*.test.js" -Recurse -ErrorAction SilentlyContinue
}
if ($testFiles.Count -eq 0) {
    Write-Warning "No test files found in $TestDirectory"
    Write-Info "Continuing anyway - you can add tests later"
} else {
    Write-Success "Found $($testFiles.Count) test file(s)"
}

# Check Node.js
try {
    $nodeVersion = node --version
    Write-Success "Node.js installed: $nodeVersion"
} catch {
    Write-Error "Node.js not found! Please install Node.js first."
    exit 1
}

# Check npm
try {
    $npmVersion = npm --version
    Write-Success "npm installed: $npmVersion"
} catch {
    Write-Error "npm not found! Please install npm first."
    exit 1
}

# Check Docker (optional)
try {
    $dockerVersion = docker --version
    Write-Success "Docker installed: $dockerVersion"
} catch {
    Write-Warning "Docker not found - you can still use local execution"
}

# Check AWS CLI (optional)
if (-not $SkipAWSDeploy) {
    try {
        $awsVersion = aws --version
        Write-Success "AWS CLI installed: $awsVersion"
    } catch {
        Write-Warning "AWS CLI not found - you'll need it for deployment"
    }
}

# Step 2: Create serverless-runner directory
Write-Step "Creating serverless-runner directory..."

if (Test-Path "serverless-runner") {
    Write-Warning "serverless-runner directory already exists - backing up..."
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Move-Item "serverless-runner" "serverless-runner.backup.$timestamp"
    Write-Info "Backup created: serverless-runner.backup.$timestamp"
}

New-Item -ItemType Directory -Path "serverless-runner" -Force | Out-Null
Write-Success "Created serverless-runner directory"

# Step 3: Create serverless-runner/package.json
Write-Step "Creating serverless-runner/package.json..."

$runnerPackageJson = @{
    name = "serverless-runner"
    version = "1.0.0"
    private = $true
    description = "Test orchestrator for AWS Lambda Playwright tests"
    scripts = @{
        start = "node ./index.js"
    }
    dependencies = @{
        "aws-sdk" = "^2.1500.0"
        "glob" = "^10.3.10"
        "signale" = "^1.4.0"
    }
} | ConvertTo-Json -Depth 10

Set-Content -Path "serverless-runner/package.json" -Value $runnerPackageJson
Write-Success "Created serverless-runner/package.json"

# Step 4: Create serverless-runner/helpers directory
Write-Step "Creating helper files..."

New-Item -ItemType Directory -Path "serverless-runner/helpers" -Force | Out-Null

# Create logger.js
$loggerJs = @'
const { Signale } = require('signale');

const signale = new Signale({
  types: {
    star: {
      badge: '/',
      label: 'executed'
    },
    success: {
      label: 'tests passed'
    },
    pending: {
      label: 'tests pending'
    },
    error: {
      label: 'tests failed'
    },
    start: {
      label: 'starting test'
    }
  }
})

signale.config({
  displayTimestamp: true,
  underlineLabel: false
})

const durationInSeconds = startTime => {
  const durationInMilliseconds = Date.now() - startTime
  const durationInSeconds = ((durationInMilliseconds % 60000) / 1000).toFixed(2)
  return `${durationInSeconds} seconds`
}

const millisToMinutesAndSeconds = millis => {
  var minutes = Math.floor(millis / 60000);
  var seconds = ((millis % 60000) / 1000).toFixed(0);
  return (minutes < 10 ? '0' : '') + minutes + ":" + (seconds < 10 ? '0' : '') + seconds;
}

function logStartTest({ numTotalFiles }) {
  signale.start(`Test will run on ${numTotalFiles} files\n`)
}

function logFileExecuted({ file, startTestTime, numExecution }) {
  numExecution = ('00' + numExecution).slice(-3)
  signale.star({ prefix: `[${numExecution}]`, message: `File "${file}" executed, took ${durationInSeconds(startTestTime)}` });
}

function logResume({ numPassedTests, numPendingTests, numFailedTests }) {
  console.log();
  signale.success(numPassedTests)
  signale.pending(numPendingTests)
  signale.error(numFailedTests)
}

function logComplete({ numTotalTests, numTotalFiles, startTestTime, totalTimeExecution }) {
  console.log();
  signale.complete(`${numTotalTests} tests on ${numTotalFiles} files executed in ${durationInSeconds(startTestTime)}\n`)
  signale.info(`Duration without serverless (mm:ss): ${millisToMinutesAndSeconds(totalTimeExecution)}`)
  const timeSavedInMillis = totalTimeExecution - (Date.now() - startTestTime)
  signale.info(`Time saved (mm:ss): ${millisToMinutesAndSeconds(timeSavedInMillis)}`)
}

function logFailedTestPattern({ testPattern }) {
  signale.fatal(`'${testPattern}' pattern entered matches no test file`)
}

module.exports = {
  logStartTest,
  logFileExecuted,
  logResume,
  logComplete,
  logFailedTestPattern,
}
'@

Set-Content -Path "serverless-runner/helpers/logger.js" -Value $loggerJs
Write-Success "Created logger.js"

# Create requester.js
$requesterJs = @'
const AWS = require('aws-sdk')
const loggers = require('./logger')

const lambda = new AWS.Lambda({
  region: process.env.AWS_REGION || 'us-east-1'
})

function runTest({ file, functionName, startTestTime, resolve }) {
  const params = {
    FunctionName: functionName,
    InvocationType: 'RequestResponse',
    Payload: JSON.stringify({ testFile: file })
  }

  const startTime = Date.now()

  lambda.invoke(params, (err, data) => {
    if (err) {
      console.error(`Error invoking Lambda for ${file}:`, err)
      resolve({
        file,
        error: err.message,
        numPassedTests: 0,
        numFailedTests: 1,
        numPendingTests: 0,
        totalTimeExecution: Date.now() - startTime
      })
      return
    }

    try {
      const response = JSON.parse(data.Payload)
      const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body
      
      resolve({
        file,
        numPassedTests: body.numPassedTests || 0,
        numFailedTests: body.numFailedTests || 0,
        numPendingTests: body.numPendingTests || 0,
        totalTimeExecution: body.totalTimeExecution || (Date.now() - startTime)
      })
    } catch (parseError) {
      console.error(`Error parsing response for ${file}:`, parseError)
      resolve({
        file,
        error: parseError.message,
        numPassedTests: 0,
        numFailedTests: 1,
        numPendingTests: 0,
        totalTimeExecution: Date.now() - startTime
      })
    }
  })
}

module.exports = {
  runTest
}
'@

Set-Content -Path "serverless-runner/helpers/requester.js" -Value $requesterJs
Write-Success "Created requester.js"

# Create utils.js
$utilsJs = @'
const glob = require('glob')
const path = require('path')

function getAllTestFilesByTestPattern({ testPattern }) {
  const files = glob.sync(testPattern, { cwd: path.join(__dirname, '../../') })
  return {
    files: files.map(f => `/app/${f}`),
    numTotalFiles: files.length
  }
}

function returnMax(allTestsResponse) {
  const numPassedTests = allTestsResponse.reduce((acc, { numPassedTests }) => acc + numPassedTests, 0)
  const numFailedTests = allTestsResponse.reduce((acc, { numFailedTests }) => acc + numFailedTests, 0)
  const numPendingTests = allTestsResponse.reduce((acc, { numPendingTests }) => acc + numPendingTests, 0)
  const totalTimeExecution = allTestsResponse.reduce((acc, { totalTimeExecution }) => acc + totalTimeExecution, 0)
  
  return {
    numPassedTests,
    numFailedTests,
    numPendingTests,
    numTotalTests: numPassedTests + numFailedTests + numPendingTests,
    totalTimeExecution
  }
}

module.exports = {
  getAllTestFilesByTestPattern,
  returnMax
}
'@

Set-Content -Path "serverless-runner/helpers/utils.js" -Value $utilsJs
Write-Success "Created utils.js"

# Step 5: Create serverless-runner/index.js
Write-Step "Creating main orchestrator (index.js)..."

$indexJs = @"
const loggers = require('./helpers/logger')
const requester = require('./helpers/requester')
const utils = require('./helpers/utils')

async function runPlaywrightTestOnServerless() {
  try {
    const testPattern = process.env.TEST_PATTERN || '$TestPattern'
    const functionName = process.env.LAMBDA_FUNCTION_NAME || 'playwright-serverless-dev-run-tests'
    
    const { files, numTotalFiles } = utils.getAllTestFilesByTestPattern({
      testPattern
    })

    if (numTotalFiles === 0) {
      loggers.logFailedTestPattern({ testPattern })
      process.exit(1)
    }

    loggers.logStartTest({ numTotalFiles })

    const startTestTime = Date.now()
    
    // Configuration for rate limiting
    const BATCH_SIZE = parseInt(process.env.BATCH_SIZE) || 5
    const DELAY_BETWEEN_BATCHES = parseInt(process.env.BATCH_DELAY) || 2000
    
    const allTestsResponse = []
    
    // Process tests in batches
    for (let i = 0; i < files.length; i += BATCH_SIZE) {
      const batch = files.slice(i, i + BATCH_SIZE)
      const batchNumber = Math.floor(i / BATCH_SIZE) + 1
      const totalBatches = Math.ceil(files.length / BATCH_SIZE)
      
      console.log(\`\nBatch \${batchNumber}/\${totalBatches}] Processing \${batch.length} tests...\`)
      
      // Create promises for current batch
      const batchPromises = batch.map((file, index) => {
        return new Promise((resolve) => {
          requester.runTest({
            file,
            functionName,
            startTestTime,
            resolve,
          })
        })
      })
      
      // Wait for current batch to complete
      const batchResults = await Promise.all(batchPromises)
      allTestsResponse.push(...batchResults)
      
      // Log each result
      batchResults.forEach((result, index) => {
        loggers.logFileExecuted({
          file: result.file,
          startTestTime: Date.now() - result.totalTimeExecution,
          numExecution: i + index + 1
        })
      })
      
      console.log(\`[Batch \${batchNumber}/\${totalBatches}] Completed\`)
      
      // Add delay between batches (except for the last batch)
      if (i + BATCH_SIZE < files.length) {
        console.log(\`Waiting \${DELAY_BETWEEN_BATCHES}ms before next batch...\`)
        await new Promise(resolve => setTimeout(resolve, DELAY_BETWEEN_BATCHES))
      }
    }
    
    // Process results
    const {
      numFailedTests,
      numPassedTests,
      numPendingTests,
      numTotalTests,
      totalTimeExecution,
    } = utils.returnMax(allTestsResponse)
    
    loggers.logResume({ numPassedTests, numFailedTests, numPendingTests })
    loggers.logComplete({
      numTotalTests, numTotalFiles, startTestTime, totalTimeExecution
    })
    
    process.exit(numFailedTests > 0 ? 1 : 0)
  } catch (e) {
    console.error(e)
    process.exit(1)
  }
}

runPlaywrightTestOnServerless()
"@

Set-Content -Path "serverless-runner/index.js" -Value $indexJs
Write-Success "Created index.js"

# Step 6: Create serverless.yml
Write-Step "Creating serverless.yml..."

$serverlessYml = @"
service: playwright-serverless

provider:
  name: aws
  runtime: nodejs18.x
  region: $AWSRegion
  timeout: 300
  memorySize: 2048
  environment:
    NODE_ENV: production

functions:
  run-tests:
    handler: lambda/index.handler
    layers:
      - arn:aws:lambda:$AWSRegion:464622532012:layer:Playwright:latest
    events:
      - http:
          path: run-test
          method: post

package:
  exclude:
    - node_modules/**
    - serverless-runner/**
    - .git/**
    - .github/**
    - '*.md'
"@

Set-Content -Path "serverless.yml" -Value $serverlessYml
Write-Success "Created serverless.yml"

# Step 7: Create Lambda handler directory
Write-Step "Creating Lambda handler..."

New-Item -ItemType Directory -Path "lambda" -Force | Out-Null

$lambdaHandler = @'
const { chromium } = require('playwright-core');

exports.handler = async (event) => {
  const startTime = Date.now();
  
  try {
    const { testFile } = typeof event.body === 'string' ? JSON.parse(event.body) : event;
    
    console.log(`Running test: ${testFile}`);
    
    // Launch browser
    const browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext();
    const page = await context.newPage();
    
    // Import and run the test
    // Note: You'll need to adapt this based on your test structure
    const testModule = require(`../${testFile}`);
    
    let numPassedTests = 0;
    let numFailedTests = 0;
    let numPendingTests = 0;
    
    try {
      // Run the test
      if (typeof testModule.default === 'function') {
        await testModule.default(page);
        numPassedTests = 1;
      } else if (typeof testModule === 'function') {
        await testModule(page);
        numPassedTests = 1;
      } else {
        throw new Error('Test file does not export a function');
      }
    } catch (error) {
      console.error('Test failed:', error);
      numFailedTests = 1;
    }
    
    await browser.close();
    
    const totalTimeExecution = Date.now() - startTime;
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        testFile,
        numPassedTests,
        numFailedTests,
        numPendingTests,
        totalTimeExecution
      })
    };
  } catch (error) {
    console.error('Lambda error:', error);
    
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: error.message,
        numPassedTests: 0,
        numFailedTests: 1,
        numPendingTests: 0,
        totalTimeExecution: Date.now() - startTime
      })
    };
  }
};
'@

Set-Content -Path "lambda/index.js" -Value $lambdaHandler
Write-Success "Created lambda/index.js"

# Step 8: Create Makefile
Write-Step "Creating Makefile..."

$makefile = @"
default: test-serverless

HOST_HOME := `$(or `$(USERPROFILE),`$(HOME))
HOST_HOME_POSIX := `$(subst \,/,`$(HOST_HOME))
HOST_AWS_DIR := `$(HOST_HOME_POSIX)/.aws

deploy:
	@serverless deploy --verbose

AWS_PROFILE ?= default

test-serverless:
	@docker run -t --rm \
		-v `$(CURDIR):/app \
		-v `$(HOST_AWS_DIR):/root/.aws:ro \
		-w /app/serverless-runner \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_PROFILE=`$(AWS_PROFILE) \
		-e AWS_SDK_LOAD_CONFIG=1 \
		node:18-alpine \
		sh -c "npm ci && npm start"
"@

Set-Content -Path "Makefile" -Value $makefile
Write-Success "Created Makefile"

# Step 9: Create helper scripts
Write-Step "Creating helper scripts..."

$runTestsScript = @'
#!/usr/bin/env pwsh

# Run serverless tests and capture full output
Set-Location serverless-runner
npm start | Tee-Object -FilePath "../test-results.log"
'@

Set-Content -Path "run-tests-with-output.ps1" -Value $runTestsScript
Write-Success "Created run-tests-with-output.ps1"

# Step 10: Create .gitignore entries
Write-Step "Updating .gitignore..."

$gitignoreEntries = @"

# AWS Lambda Serverless
.serverless/
serverless-runner/node_modules/
lambda/node_modules/
test-results.log
*.backup.*
"@

if (Test-Path ".gitignore") {
    Add-Content -Path ".gitignore" -Value $gitignoreEntries
} else {
    Set-Content -Path ".gitignore" -Value $gitignoreEntries
}
Write-Success "Updated .gitignore"

# Step 11: Install dependencies
Write-Step "Installing serverless-runner dependencies..."

Push-Location serverless-runner
try {
    npm install
    Write-Success "Dependencies installed successfully"
} catch {
    Write-Error "Failed to install dependencies: $_"
} finally {
    Pop-Location
}

# Step 12: Check for Serverless Framework
Write-Step "Checking Serverless Framework..."

try {
    $slsVersion = serverless --version
    Write-Success "Serverless Framework installed: $slsVersion"
} catch {
    Write-Warning "Serverless Framework not found"
    Write-Info "Install with: npm install -g serverless"
}

# Step 13: Summary and next steps
Write-Host "`n"
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                               ║" -ForegroundColor Green
Write-Host "║   ✅ Setup Complete!                                          ║" -ForegroundColor Green
Write-Host "║                                                               ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📁 Files Created:" -ForegroundColor Cyan
Write-Host "  ├─ serverless-runner/          (Test orchestrator)"
Write-Host "  │  ├─ package.json"
Write-Host "  │  ├─ index.js"
Write-Host "  │  └─ helpers/"
Write-Host "  ├─ lambda/                     (Lambda function)"
Write-Host "  │  └─ index.js"
Write-Host "  ├─ serverless.yml              (AWS configuration)"
Write-Host "  ├─ Makefile                    (Build commands)"
Write-Host "  └─ run-tests-with-output.ps1   (Helper script)"

Write-Host "`n🚀 Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣  Configure AWS credentials:" -ForegroundColor White
Write-Host "   aws configure" -ForegroundColor Gray
Write-Host ""
Write-Host "2️⃣  Install Serverless Framework (if not installed):" -ForegroundColor White
Write-Host "   npm install -g serverless" -ForegroundColor Gray
Write-Host ""
Write-Host "3️⃣  Customize lambda/index.js for your test structure" -ForegroundColor White
Write-Host ""

if (-not $SkipAWSDeploy) {
    Write-Host "4️⃣  Deploy to AWS Lambda:" -ForegroundColor White
    Write-Host "   serverless deploy --verbose" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5️⃣  Run tests:" -ForegroundColor White
    Write-Host "   make test-serverless          (Docker + AWS Lambda)" -ForegroundColor Gray
    Write-Host "   cd serverless-runner && npm start  (Local + AWS Lambda)" -ForegroundColor Gray
} else {
    Write-Host "4️⃣  When ready, deploy to AWS Lambda:" -ForegroundColor White
    Write-Host "   serverless deploy --verbose" -ForegroundColor Gray
}

Write-Host ""
Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "  See the original project for detailed guides:" -ForegroundColor Gray
Write-Host "  - QUICK-START.md" -ForegroundColor Gray
Write-Host "  - SETUP-GUIDE.md" -ForegroundColor Gray
Write-Host "  - TESTING-TYPES.md" -ForegroundColor Gray
Write-Host ""

Write-Host "⚙️  Configuration:" -ForegroundColor Cyan
Write-Host "  Test Pattern: $TestPattern" -ForegroundColor Gray
Write-Host "  Test Directory: $TestDirectory" -ForegroundColor Gray
Write-Host "  AWS Region: $AWSRegion" -ForegroundColor Gray
Write-Host ""

Write-Success "Setup script completed successfully!"
