const { expect } = require('@playwright/test');

const TODO_ITEMS = [
  'buy some cheese',
  'feed the cat',
  'book a doctors appointment'
];

async function checkNumberOfTodosInLocalStorage(page, expected) {
  return await page.waitForFunction(e => {
    return JSON.parse(localStorage['react-todos']).length === e;
  }, expected);
}

async function checkNumberOfCompletedTodosInLocalStorage(page, expected) {
  return await page.waitForFunction(e => {
    return JSON.parse(localStorage['react-todos']).filter(todo => todo.completed).length === e;
  }, expected);
}

async function checkTodosInLocalStorage(page, title) {
  return await page.waitForFunction(t => {
    return JSON.parse(localStorage['react-todos']).map(todo => todo.title).includes(t);
  }, title);
}

async function createDefaultTodos(page) {
  const newTodo = page.getByPlaceholder('What needs to be done?');
  for (const item of TODO_ITEMS) {
    await newTodo.fill(item);
    await newTodo.press('Enter');
  }
}

module.exports = async (page) => {
  console.log('Running Todo App Tests');
  
  // Initial setup (from beforeEach)
  await page.goto('https://demo.playwright.dev/todomvc');

  // Test: should allow me to add todo items
  console.log('Test: should allow me to add todo items');
  const newTodo = page.getByPlaceholder('What needs to be done?');
  await newTodo.fill(TODO_ITEMS[0]);
  await newTodo.press('Enter');
  await expect(page.getByTestId('todo-title')).toHaveText([TODO_ITEMS[0]]);
  
  await newTodo.fill(TODO_ITEMS[1]);
  await newTodo.press('Enter');
  await expect(page.getByTestId('todo-title')).toHaveText([TODO_ITEMS[0], TODO_ITEMS[1]]);
  await checkNumberOfTodosInLocalStorage(page, 2);

  // Test: should clear text input field when an item is added
  console.log('Test: should clear text input field when an item is added');
  await newTodo.fill(TODO_ITEMS[2]);
  await newTodo.press('Enter');
  await expect(newTodo).toBeEmpty();
  await checkNumberOfTodosInLocalStorage(page, 3);

  // Mark all as completed suite
  console.log('Test Suite: Mark all as completed');
  
  // Test: should allow me to mark all items as completed
  console.log('Test: should allow me to mark all items as completed');
  await page.getByLabel('Mark all as complete').check();
  await expect(page.getByTestId('todo-item')).toHaveClass(['completed', 'completed', 'completed']);
  await checkNumberOfCompletedTodosInLocalStorage(page, 3);

  // Test: should allow me to clear the complete state of all items
  console.log('Test: should allow me to clear the complete state of all items');
  const toggleAll = page.getByLabel('Mark all as complete');
  await toggleAll.uncheck();
  await expect(page.getByTestId('todo-item')).toHaveClass(['', '', '']);
};
