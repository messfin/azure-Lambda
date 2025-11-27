const { expect } = require('@playwright/test');

module.exports = async (page) => {
  // Test 1: has title
  console.log('Running test: has title');
  await page.goto('https://playwright.dev/');
  await expect(page).toHaveTitle(/Playwright/);

  // Test 2: get started link
  console.log('Running test: get started link');
  await page.goto('https://playwright.dev/');
  await page.getByRole('link', { name: 'Get started' }).click();
  await expect(page.getByRole('heading', { name: 'Installation' })).toBeVisible();
};
