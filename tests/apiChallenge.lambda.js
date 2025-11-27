const { expect } = require('@playwright/test');

module.exports = async (page) => {
  console.log('Running apiChallenge test...');
  const apiUrl = "https://api.practicesoftwaretesting.com";
  
  // Use page.request for API calls since we have the page object
  const getProductResponse = await page.request.get(
    apiUrl + "/products/search?q=thor%20hammer"
  );
  expect(getProductResponse.status()).toBe(200);
  const productBody = await getProductResponse.json();
  const productId = productBody.data[0].id;

  const response = await page.request.get(apiUrl + "/products/" + productId);

  expect(response.status()).toBe(200);
  const body = await response.json();

  expect(body.in_stock).toBe(true);
  expect(body.is_location_offer).toBe(false);
  expect(body.is_rental).toBe(false);
  expect(body.name).toBe("Thor Hammer");
  expect(body.price).toBe(11.14);
  
  console.log('Test completed successfully');
};
