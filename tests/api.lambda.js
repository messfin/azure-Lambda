const { expect } = require('@playwright/test');

module.exports = async (page) => {
  console.log('Running API tests...');
  const apiUrl = "https://api.practicesoftwaretesting.com";

  // Test: GET /products
  console.log('Test: GET /products');
  const responseProducts = await page.request.get(apiUrl + "/products");
  expect(responseProducts.status()).toBe(200);
  const bodyProducts = await responseProducts.json();
  expect(bodyProducts.data.length).toBe(9);
  expect(bodyProducts.total).toBe(53);

  // Test: POST /users/login
  console.log('Test: POST /users/login');
  const responseLogin = await page.request.post(apiUrl + "/users/login", {
    data: {
      email: "customer@practicesoftwaretesting.com",
      password: "welcome01",
    },
  });
  expect(responseLogin.status()).toBe(200);
  const bodyLogin = await responseLogin.json();
  expect(bodyLogin.access_token).toBeTruthy();
  
  console.log('API tests completed successfully');
};
