const { chromium } = require('@playwright/test');
const path = require('path');

module.exports.runTest = async (event) => {
  let browser = null;
  try {
    const { testMatch } = event.body;
    if (!testMatch) {
      return {
        statusCode: 400,
        body: JSON.stringify('Property \'testMatch\' not found.')
      };
    }

    console.log(`Running test file: ${testMatch}`);
    
    // Launch browser
    // Note: In Lambda, we might need specific args for Chromium
    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--single-process' // Often needed in Lambda
      ]
    });

    const context = await browser.newContext();
    const page = await context.newPage();

    // Resolve the test file path
    // Assuming testMatch is relative like 'tests/demo.lambda.js'
    // and we copied tests/ to ${LAMBDA_TASK_ROOT}/tests/
    const testFilePath = path.resolve(__dirname, testMatch);
    
    console.log(`Requiring test module from: ${testFilePath}`);
    const testFn = require(testFilePath);

    if (typeof testFn !== 'function') {
      throw new Error(`Test file ${testMatch} does not export a function.`);
    }

    // Run the test
    const startTime = Date.now();
    await testFn(page);
    const duration = Date.now() - startTime;

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        duration,
        testMatch
      })
    };

  } catch (error) {
    console.error('Test execution failed:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        success: false,
        error: error.message,
        stack: error.stack
      })
    };
  } finally {
    if (browser) {
      await browser.close();
    }
  }
};
