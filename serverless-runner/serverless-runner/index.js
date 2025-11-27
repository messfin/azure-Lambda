const loggers = require('./helpers/logger')
const requester = require('./helpers/requester')
const utils = require('./helpers/utils')

async function runPlaywrightTestOnServerless() {
  try {
    const testPattern = 'E2E/*.test.js'
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
    const BATCH_SIZE = 5 // Run 5 tests concurrently
    const DELAY_BETWEEN_BATCHES = 2000 // 2 seconds delay between batches
    
    const allTestsResponse = []
    
    // Process tests in batches
    for (let i = 0; i < files.length; i += BATCH_SIZE) {
      const batch = files.slice(i, i + BATCH_SIZE)
      const batchNumber = Math.floor(i / BATCH_SIZE) + 1
      const totalBatches = Math.ceil(files.length / BATCH_SIZE)
      
      console.log(`\n[Batch ${batchNumber}/${totalBatches}] Processing ${batch.length} tests...`)
      
      // Create promises for current batch
      const batchPromises = batch.map((file) => {
        return new Promise((resolve) => {
          requester.runTest({
            file,
            functionName: 'playwright-serverless-dev-run-tests',
            startTestTime,
            resolve,
          })
        })
      })
      
      // Wait for current batch to complete
      const batchResults = await Promise.all(batchPromises)
      allTestsResponse.push(...batchResults)
      
      console.log(`[Batch ${batchNumber}/${totalBatches}] Completed`)
      
      // Add delay between batches (except for the last batch)
      if (i + BATCH_SIZE < files.length) {
        console.log(`Waiting ${DELAY_BETWEEN_BATCHES}ms before next batch...`)
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
    
    process.exit(0)
  } catch (e) {
    console.error(e)
    process.exit(1)
  }
}

runPlaywrightTestOnServerless()