#!/bin/bash

# Bootstrap AWS Lambda + Playwright infrastructure into an existing project
# This script sets up the serverless test infrastructure for running Playwright tests
# on AWS Lambda. It assumes you already have Playwright tests in your project.

set -e

# Default parameters
TEST_DIRECTORY="${TEST_DIRECTORY:-tests}"
TEST_PATTERN="${TEST_PATTERN:-**/*.spec.js}"
SKIP_AWS_DEPLOY="${SKIP_AWS_DEPLOY:-false}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Color output functions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
step() { echo -e "\n${BLUE}🔹 $1${NC}"; }

echo -e "${MAGENTA}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   AWS Lambda + Playwright Test Infrastructure Setup          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test-directory)
            TEST_DIRECTORY="$2"
            shift 2
            ;;
        --test-pattern)
            TEST_PATTERN="$2"
            shift 2
            ;;
        --skip-aws-deploy)
            SKIP_AWS_DEPLOY=true
            shift
            ;;
        --aws-region)
            AWS_REGION="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --test-directory DIR    Directory containing test files (default: tests)"
            echo "  --test-pattern PATTERN  Glob pattern for test files (default: **/*.spec.js)"
            echo "  --skip-aws-deploy       Skip AWS Lambda deployment"
            echo "  --aws-region REGION     AWS region (default: us-east-1)"
            echo "  --help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --test-directory e2e --test-pattern '**/*.test.ts'"
            echo "  $0 --skip-aws-deploy"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Step 1: Verify prerequisites
step "Checking prerequisites..."

# Check if test directory exists
if [ ! -d "$TEST_DIRECTORY" ]; then
    error "Test directory '$TEST_DIRECTORY' not found!"
    info "Please specify the correct test directory with --test-directory parameter"
    exit 1
fi
success "Test directory found: $TEST_DIRECTORY"

# Check for test files
TEST_FILE_COUNT=$(find "$TEST_DIRECTORY" -name "*.spec.js" -o -name "*.test.js" 2>/dev/null | wc -l)
if [ "$TEST_FILE_COUNT" -eq 0 ]; then
    warning "No test files found in $TEST_DIRECTORY"
    info "Continuing anyway - you can add tests later"
else
    success "Found $TEST_FILE_COUNT test file(s)"
fi

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    success "Node.js installed: $NODE_VERSION"
else
    error "Node.js not found! Please install Node.js first."
    exit 1
fi

# Check npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    success "npm installed: $NPM_VERSION"
else
    error "npm not found! Please install npm first."
    exit 1
fi

# Check Docker (optional)
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    success "Docker installed: $DOCKER_VERSION"
else
    warning "Docker not found - you can still use local execution"
fi

# Check AWS CLI (optional)
if [ "$SKIP_AWS_DEPLOY" != "true" ]; then
    if command -v aws &> /dev/null; then
        AWS_VERSION=$(aws --version)
        success "AWS CLI installed: $AWS_VERSION"
    else
        warning "AWS CLI not found - you'll need it for deployment"
    fi
fi

# Step 2: Create serverless-runner directory
step "Creating serverless-runner directory..."

if [ -d "serverless-runner" ]; then
    warning "serverless-runner directory already exists - backing up..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mv serverless-runner "serverless-runner.backup.$TIMESTAMP"
    info "Backup created: serverless-runner.backup.$TIMESTAMP"
fi

mkdir -p serverless-runner
success "Created serverless-runner directory"

# Step 3: Create serverless-runner/package.json
step "Creating serverless-runner/package.json..."

cat > serverless-runner/package.json << 'EOF'
{
  "name": "serverless-runner",
  "version": "1.0.0",
  "private": true,
  "description": "Test orchestrator for AWS Lambda Playwright tests",
  "scripts": {
    "start": "node ./index.js"
  },
  "dependencies": {
    "aws-sdk": "^2.1500.0",
    "glob": "^10.3.10",
    "signale": "^1.4.0"
  }
}
EOF

success "Created serverless-runner/package.json"

# Step 4: Create serverless-runner/helpers directory
step "Creating helper files..."

mkdir -p serverless-runner/helpers

# Create logger.js
cat > serverless-runner/helpers/logger.js << 'EOF'
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
EOF

success "Created logger.js"

# Create requester.js (same content as PowerShell version)
cat > serverless-runner/helpers/requester.js << 'EOF'
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
EOF

success "Created requester.js"

# Create utils.js
cat > serverless-runner/helpers/utils.js << 'EOF'
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
EOF

success "Created utils.js"

# Step 5: Create serverless-runner/index.js
step "Creating main orchestrator (index.js)..."

cat > serverless-runner/index.js << EOF
const loggers = require('./helpers/logger')
const requester = require('./helpers/requester')
const utils = require('./helpers/utils')

async function runPlaywrightTestOnServerless() {
  try {
    const testPattern = process.env.TEST_PATTERN || '$TEST_PATTERN'
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
      
      console.log(\`\\n[Batch \${batchNumber}/\${totalBatches}] Processing \${batch.length} tests...\`)
      
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
EOF

success "Created index.js"

# Continue with remaining steps...
step "Creating serverless.yml..."

cat > serverless.yml << EOF
service: playwright-serverless

provider:
  name: aws
  runtime: nodejs18.x
  region: $AWS_REGION
  timeout: 300
  memorySize: 2048
  environment:
    NODE_ENV: production

functions:
  run-tests:
    handler: lambda/index.handler
    layers:
      - arn:aws:lambda:$AWS_REGION:464622532012:layer:Playwright:latest
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
EOF

success "Created serverless.yml"

# Create Lambda handler
step "Creating Lambda handler..."

mkdir -p lambda

cat > lambda/index.js << 'EOF'
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
EOF

success "Created lambda/index.js"

# Create Makefile
step "Creating Makefile..."

cat > Makefile << 'EOF'
default: test-serverless

HOST_HOME := $(or $(USERPROFILE),$(HOME))
HOST_HOME_POSIX := $(subst \,/,$(HOST_HOME))
HOST_AWS_DIR := $(HOST_HOME_POSIX)/.aws

deploy:
	@serverless deploy --verbose

AWS_PROFILE ?= default

test-serverless:
	@docker run -t --rm \
		-v $(CURDIR):/app \
		-v $(HOST_AWS_DIR):/root/.aws:ro \
		-w /app/serverless-runner \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_PROFILE=$(AWS_PROFILE) \
		-e AWS_SDK_LOAD_CONFIG=1 \
		node:18-alpine \
		sh -c "npm ci && npm start"
EOF

success "Created Makefile"

# Create helper script
step "Creating helper scripts..."

cat > run-tests-with-output.sh << 'EOF'
#!/bin/bash
# Run serverless tests and capture full output
cd serverless-runner
npm start | tee ../test-results.log
EOF

chmod +x run-tests-with-output.sh
success "Created run-tests-with-output.sh"

# Update .gitignore
step "Updating .gitignore..."

cat >> .gitignore << 'EOF'

# AWS Lambda Serverless
.serverless/
serverless-runner/node_modules/
lambda/node_modules/
test-results.log
*.backup.*
EOF

success "Updated .gitignore"

# Install dependencies
step "Installing serverless-runner dependencies..."

cd serverless-runner
npm install
success "Dependencies installed successfully"
cd ..

# Check for Serverless Framework
step "Checking Serverless Framework..."

if command -v serverless &> /dev/null; then
    SLS_VERSION=$(serverless --version)
    success "Serverless Framework installed: $SLS_VERSION"
else
    warning "Serverless Framework not found"
    info "Install with: npm install -g serverless"
fi

# Summary
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ✅ Setup Complete!                                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}📁 Files Created:${NC}"
echo "  ├─ serverless-runner/          (Test orchestrator)"
echo "  │  ├─ package.json"
echo "  │  ├─ index.js"
echo "  │  └─ helpers/"
echo "  ├─ lambda/                     (Lambda function)"
echo "  │  └─ index.js"
echo "  ├─ serverless.yml              (AWS configuration)"
echo "  ├─ Makefile                    (Build commands)"
echo "  └─ run-tests-with-output.sh    (Helper script)"

echo ""
echo -e "${YELLOW}🚀 Next Steps:${NC}"
echo ""
echo -e "1️⃣  Configure AWS credentials:"
echo -e "   ${NC}aws configure${NC}"
echo ""
echo -e "2️⃣  Install Serverless Framework (if not installed):"
echo -e "   ${NC}npm install -g serverless${NC}"
echo ""
echo -e "3️⃣  Customize lambda/index.js for your test structure"
echo ""

if [ "$SKIP_AWS_DEPLOY" != "true" ]; then
    echo -e "4️⃣  Deploy to AWS Lambda:"
    echo -e "   ${NC}serverless deploy --verbose${NC}"
    echo ""
    echo -e "5️⃣  Run tests:"
    echo -e "   ${NC}make test-serverless${NC}          (Docker + AWS Lambda)"
    echo -e "   ${NC}cd serverless-runner && npm start${NC}  (Local + AWS Lambda)"
else
    echo -e "4️⃣  When ready, deploy to AWS Lambda:"
    echo -e "   ${NC}serverless deploy --verbose${NC}"
fi

echo ""
echo -e "${CYAN}📚 Documentation:${NC}"
echo -e "  See the original project for detailed guides:"
echo -e "  - QUICK-START.md"
echo -e "  - SETUP-GUIDE.md"
echo -e "  - TESTING-TYPES.md"
echo ""

echo -e "${CYAN}⚙️  Configuration:${NC}"
echo -e "  Test Pattern: $TEST_PATTERN"
echo -e "  Test Directory: $TEST_DIRECTORY"
echo -e "  AWS Region: $AWS_REGION"
echo ""

success "Setup script completed successfully!"
