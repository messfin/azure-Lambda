# Minimal Setup Script for AWS Lambda + Playwright
param(
    [string]$TestDirectory = "tests",
    [string]$TestPattern = "**/*.spec.js"
)

Write-Host "Setting up AWS Lambda infrastructure..." -ForegroundColor Cyan
Write-Host "Test Directory: $TestDirectory" -ForegroundColor Gray
Write-Host "Test Pattern: $TestPattern" -ForegroundColor Gray
Write-Host ""

# Create directories
Write-Host "Creating directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "serverless-runner/helpers" -Force | Out-Null
New-Item -ItemType Directory -Path "lambda" -Force | Out-Null

Write-Host "Setup complete! Files created in current directory." -ForegroundColor Green
Write-Host "Check the QUICK-SETUP.md file for next steps." -ForegroundColor Cyan
