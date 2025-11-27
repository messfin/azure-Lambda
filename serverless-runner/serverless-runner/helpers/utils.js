const glob = require("glob")

function convertTestResponseToObject(response) {
  if (!response || typeof response.Payload === 'undefined') {
    throw new Error('Lambda invocation returned an empty payload.')
  }

  let payloadString

  if (Buffer.isBuffer(response.Payload)) {
    payloadString = response.Payload.toString('utf8')
  } else if (typeof response.Payload === 'string') {
    payloadString = response.Payload
  } else {
    payloadString = JSON.stringify(response.Payload)
  }

  let parsedPayload
  try {
    parsedPayload = JSON.parse(payloadString)
  } catch (error) {
    throw new Error(`Unable to parse Lambda payload: ${payloadString}`)
  }

  let bodyCandidate = typeof parsedPayload.body !== 'undefined'
    ? parsedPayload.body
    : parsedPayload

  if (typeof bodyCandidate === 'object') {
    return bodyCandidate
  }

  try {
    return JSON.parse(bodyCandidate)
  } catch (error) {
    throw new Error(`Unable to parse Lambda body: ${bodyCandidate}`)
  }
}

function returnMax(array) {
  return {
    numFailedTests: Math.max.apply(Math, array.map((o) => o.numFailedTests)),
    numPassedTests: Math.max.apply(Math, array.map((o) => o.numPassedTests)),
    numPendingTests: Math.max.apply(Math, array.map((o) => o.numPendingTests)),
    numTotalTests: Math.max.apply(Math, array.map((o) => o.numTotalTests)),
    totalTimeExecution: Math.max.apply(Math, array.map((o) => o.totalTimeExecution)),
  }
}

function getAllTestFilesByTestPattern({ testPattern }) {
  const files = glob
    .sync(testPattern, {
      cwd: "../tests"
    })
    .map(file => `/app/${file}`)
  return {
    files,
    numTotalFiles: files.length,
  }
}

module.exports = {
  convertTestResponseToObject,
  getAllTestFilesByTestPattern,
  returnMax,
}
