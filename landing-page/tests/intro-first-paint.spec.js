import { test, expect } from '@playwright/test';
test('critical intro survives delayed or failed module loading without a landing-page flash', async ({ page }) => {
  await page.emulateMedia({reducedMotion:'no-preference'});
  // This prevents the deferred application from mounting anything at all.
  await page.route('**/*.js', route => route.abort());
  await page.goto('/');
  await expect(page.locator('#welcome-intro')).toBeVisible();
  await expect(page.locator('main')).toBeHidden();
  await expect(page.locator('.site-header')).toBeHidden();
  expect(await page.evaluate(()=>getComputedStyle(document.documentElement).backgroundColor)).toBe('rgb(20, 12, 20)');
  await expect(page.getByRole('button',{name:'Skip intro',exact:true})).toHaveCount(0);
  await page.keyboard.press('Escape');
  await expect(page.locator('main')).toBeVisible();
});
test('intro completes naturally before hero reveals; refresh starts with intro again', async ({ page }) => {
  await page.emulateMedia({reducedMotion:'no-preference'});
  await page.goto('/');
  await expect(page.locator('main')).toBeHidden();
  await expect(page.locator('html')).toHaveAttribute('data-intro','done',{timeout:6000});
  await expect(page.locator('main')).toBeVisible();
  expect(await page.evaluate(()=>scrollY)).toBe(0);
  await page.reload();
  await expect(page.locator('main')).toBeHidden();
  await page.keyboard.press('Escape');
  await expect(page.locator('main')).toBeVisible();
});
