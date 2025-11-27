import { test, expect } from "@playwright/test";

// Define interfaces for expected API responses
interface ProductResponse {
    data: any[];
    total: number;
}

interface LoginResponse {
    access_token: string;
}

test.use({ baseURL: "https://api.practicesoftwaretesting.com" });

test.describe("API Tests", () => {
    test("GET /products", async ({ request }) => {
        const response = await request.get("/products");

        expect(response.status()).toBe(200);
        const body: ProductResponse = await response.json();
        expect(body.data.length).toBe(9);
        expect(body.total).toBe(53);
    });

    test("POST /users/login", async ({ request }) => {
        const response = await request.post("/users/login", {
            data: {
                email: "customer@practicesoftwaretesting.com",
                password: "welcome01",
            },
        });

        expect(response.status()).toBe(200);
        const body: LoginResponse = await response.json();
        expect(body.access_token).toBeTruthy();
    });
});
