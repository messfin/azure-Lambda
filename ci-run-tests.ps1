# Cross-platform CI/CD test runner for Lambda Playwright tests (PowerShell)
# Usage: .\ci-run-tests.ps1

param(
    [string]$LambdaFunctionName = "playwright-serverless-dev-run-tests",
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"

# Test files to run
$tests = @(
    "tests/simple.js",
    "tests/demo.lambda.js",
    "tests/example.lambda.js",
    "tests/api.lambda.js",
    "tests/apiChallenge.lambda.js",
    "tests/demo-todo-app.lambda.js",
    "tests/api-gravity.lambda.js"
)

# Counters
$failed = 0
$passed = 0
$total = $tests.Count

Write-Host "🚀 Starting Lambda Playwright Tests" -ForegroundColor Cyan
Write-Host "Function: $LambdaFunctionName"
Write-Host "Region: $AwsRegion"
Write-Host "Total tests: $total"
Write-Host ""

# Check if AWS CLI is available
$awsCliPath = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
if (-not (Test-Path $awsCliPath)) {
    # Try to find AWS CLI in PATH
    $awsCli = Get-Command aws -ErrorAction SilentlyContinue
    if ($awsCli) {
        $awsCliPath = $awsCli.Path
    } else {
        Write-Host "❌ AWS CLI is not installed" -ForegroundColor Red
        exit 1
    }
}

# Run each test
foreach ($test in $tests) {
    Write-Host "🧪 Running: $test" -ForegroundColor Cyan
    
    try {
        # Create payload
        $payload = @{
            body = @{
                testMatch = $test
            }
        } | ConvertTo-Json -Depth 3
        
        $payload | Out-File -FilePath test-payload.json -Encoding utf8
        
        # Invoke Lambda
        $responseFile = "response-$($test.Replace('/', '-').Replace('.', '-')).json"
        
        & $awsCliPath lambda invoke `
            --function-name $LambdaFunctionName `
            --cli-binary-format raw-in-base64-out `
            --payload file://test-payload.json `
            --region $AwsRegion `
            $responseFile | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            # Parse response
            $result = Get-Content $responseFile | ConvertFrom-Json
            
            if ($result.statusCode -eq 200) {
                $body = $result.body | ConvertFrom-Json
                
                if ($body.success -eq $true) {
                    Write-Host "✅ Passed - Duration: $($body.duration)ms" -ForegroundColor Green
                    $passed++
                } else {
                    $errorMsg = if ($body.error) { $body.error } else { "Test failed" }
                    Write-Host "❌ Failed - $errorMsg" -ForegroundColor Red
                    $failed++
                }
            } else {
                Write-Host "❌ Lambda invocation failed with status: $($result.statusCode)" -ForegroundColor Red
                $failed++
            }
        } else {
            Write-Host "❌ Failed to invoke Lambda function" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "❌ Error: $_" -ForegroundColor Red
        $failed++
    }
    
    Write-Host ""
}

# Summary
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Test Summary" -ForegroundColor Cyan
Write-Host "Total:   $total"
Write-Host "Passed:  $passed" -ForegroundColor Green
Write-Host "Failed:  $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Exit with error if any tests failed
if ($failed -gt 0) {
    Write-Host "❌ Some tests failed. Exiting with code 1." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
}

