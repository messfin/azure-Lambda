#!/usr/bin/env pwsh

# Run serverless tests and capture full output
Set-Location serverless-runner
npm start | Tee-Object -FilePath "../test-results.log"
