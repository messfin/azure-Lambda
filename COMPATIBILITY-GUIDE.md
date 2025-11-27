# Compatibility Guide for D:\Azure-test

## ⚠️ The Issue

Your project uses standard **Playwright Test** syntax (`import { test } ...`), but this Serverless runner expects **Function Exports**.

## 🔄 How to Adapt Your Tests

You have two options:

### Option 1: Refactor Tests (Recommended for this Runner)

Convert your tests to export a single async function.

**Before (Standard Playwright):**

```typescript
import { test, expect } from "@playwright/test";

test("login test", async ({ page }) => {
  await page.goto("https://example.com");
  await expect(page).toHaveTitle("Example");
});
```

**After (Serverless Compatible):**

```javascript
// apiChallenge.lambda.js
const { expect } = require("@playwright/test"); // You might need to mock expect or use a different assertion lib

module.exports = async (page) => {
  await page.goto("https://example.com");
  // Simple assertions
  const title = await page.title();
  if (title !== "Example") throw new Error("Wrong title");
};
```

### Option 2: TypeScript Support

Since your tests are in TypeScript (`.ts`), they cannot be run directly by the Node.js Lambda runtime without compilation.

1. **Compile your tests** to JavaScript before deploying:
   ```bash
   npx tsc
   ```
2. **Update your test pattern** to point to the _compiled_ `.js` files (e.g., `dist/**/*.js`).

## 🚀 Recommended Next Steps

1. **Create a sample compatible test** to verify the infrastructure works:
   Create `tests/health-check.js`:

   ```javascript
   module.exports = async (page) => {
     await page.goto("https://google.com");
     console.log("Page loaded!");
   };
   ```

2. **Run the setup:**

   ```powershell
   cd D:\Azure-test
   # Deploy
   serverless deploy
   # Run
   make test-serverless
   ```

3. **Migrate tests gradually** if you decide to stick with this Serverless architecture.
