module.exports = async (page) => {
  console.log('🚀 Starting verification test...');
  
  const startTime = Date.now();
  await page.goto('https://example.com');
  
  const title = await page.title();
  console.log(`Page title: ${title}`);
  
  if (title !== 'Example Domain') {
    throw new Error(`Expected title "Example Domain" but got "${title}"`);
  }
  
  console.log('✅ Verification test passed!');
  return {
    success: true,
    duration: Date.now() - startTime
  };
};
