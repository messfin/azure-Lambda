# Test Converter Script
# Converts Playwright .spec.ts files to AWS Lambda compatible .js files

param(
    [string]$SourceDir = "D:\Azure-test\tests"
)

Write-Host "Starting test conversion in $SourceDir..." -ForegroundColor Cyan

# Ensure output directory exists
if (-not (Test-Path $SourceDir)) {
    Write-Host "Error: Directory $SourceDir not found!" -ForegroundColor Red
    exit 1
}

$files = Get-ChildItem -Path $SourceDir -Filter "*.spec.ts" -Recurse

foreach ($file in $files) {
    Write-Host "Converting $($file.Name)..." -ForegroundColor Yellow
    
    $content = Get-Content $file.FullName -Raw
    
    # 1. Extract imports (we might need expect)
    # For simplicity, we'll assume we need to require expect if it's used
    $hasExpect = $content -match "expect"
    
    # 2. Extract the test body
    # Regex to find: test('name', async ({ page }) => { ... });
    # This is a simple regex and might need adjustment for complex files
    if ($content -match "test\s*\(\s*['`"].*?['`"]\s*,\s*async\s*\(\s*\{\s*page\s*\}\s*\)\s*=>\s*\{([\s\S]*?)\}\s*\)\s*;?") {
        $body = $matches[1]
        
        # 3. Construct the new file content
        $newContent = ""
        
        if ($hasExpect) {
            $newContent += "const { expect } = require('@playwright/test');`n`n"
        }
        
        $newContent += "module.exports = async (page) => {`n"
        $newContent += $body
        $newContent += "`n};"
        
        # 4. Save as .lambda.js
        $newName = $file.Name -replace "\.spec\.ts$", ".lambda.js"
        $newPath = Join-Path $file.Directory.FullName $newName
        
        Set-Content -Path $newPath -Value $newContent
        Write-Host "  ✅ Created $newName" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Could not parse test body in $($file.Name). It might have a complex structure." -ForegroundColor Red
    }
}

Write-Host "`nConversion complete!" -ForegroundColor Cyan
Write-Host "You can now update your configuration to run these tests:" -ForegroundColor Gray
Write-Host "const testPattern = 'tests/**/*.lambda.js'" -ForegroundColor Gray
