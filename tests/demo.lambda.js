const { expect } = require("@playwright/test");

module.exports = async (page) => {
  // beforeEach
  await page.goto("https://www.saucedemo.com/");

  // Verify Login Error Message
  console.log("Running test: Verify Login Error Message");
  await page.waitForSelector("#user-name", { state: "visible" });
  await page.locator('[data-test="username"]').type("example1@example.com");
  await page.locator('[data-test="password"]').type("examplepassword");
  await page.locator('[data-test="login-button"]').click();
  const errorMessage = await page.locator('[data-test="error"]').textContent();
  console.log("Login Error Message: " + errorMessage);
  expect(errorMessage).toBe(
    "Epic sadface: Username and password do not match any user in this service"
  );
};
