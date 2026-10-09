import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

async function revealPage(page) {
  await page.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 650) {
      window.scrollTo({ top: y, behavior: 'instant' });
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    window.scrollTo({ top: 0, behavior: 'instant' });
  });
}

test('the complete page loads without broken assets, runtime errors, or backend traffic', async ({ page }) => {
  const errors = [];
  const failures = [];
  const requests = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('response', (response) => { if (response.status() >= 400) failures.push(response.url()); });
  page.on('request', (request) => requests.push(request.url()));
  await page.goto('/');
  await expect(page).toHaveTitle('USpace — Your Love, Your Space.');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Your Love,Your Space.');
  await revealPage(page);
  await page.waitForLoadState('networkidle');
  expect(await page.locator('img').evaluateAll((images) => images.filter((img) => img.getClientRects().length && (!img.complete || !img.naturalWidth)).map((img) => img.src))).toEqual([]);
  expect(errors).toEqual([]);
  expect(failures).toEqual([]);
  expect(requests.filter((url) => !url.startsWith('http://127.0.0.1:4173/'))).toEqual([]);
  expect(await page.locator('a[href^="#"]').evaluateAll((links) => links.filter((link) => !document.getElementById(link.hash.slice(1))).map((link) => link.hash))).toEqual([]);
  await expect(page.getByRole('link', { name: /^Open USpace/ })).toHaveAttribute('href', 'https://h1enz.github.io/USpace/');
});

test('all six preview screens switch with mouse and keyboard and match their content', async ({ page }) => {
  await page.goto('/');
  const screens = [
    ['Moods', 'Let them in on how you’re feeling.', null],
    ['Chat', 'From “good morning” to “still awake?”', 'chat.webp'],
    ['Bucket List', 'Make plans for your kind of adventure.', 'bucket-list.webp'],
    ['Love Notes', 'A small note. A lasting feeling.', 'love-notes.webp'],
    ['Time Capsules', 'Today’s words. Tomorrow’s butterflies.', null],
    ['Timeline', 'Because “remember when” deserves a home.', null],
  ];
  for (const [name, title, file] of screens) {
    const tab = page.getByRole('tab', { name, exact: true });
    await tab.click();
    await expect(tab).toHaveAttribute('aria-selected', 'true');
    await expect(page.locator('#preview-title')).toHaveText(title);
    if (file) {
      await expect(page.locator('#preview-image')).toBeVisible();
      await expect(page.locator('#preview-image')).toHaveAttribute('src', new RegExp(`${file}$`));
      await expect(page.locator('#preview-image')).toHaveJSProperty('complete', true);
    } else if (name === 'Moods') {
      await expect(page.locator('#preview-image')).toBeHidden();
      await expect(page.locator('.gallery-mood-demo')).toBeVisible();
    } else if (name === 'Time Capsules') {
      await expect(page.locator('.capsule-experience')).toBeVisible();
      await expect(page.locator('.capsule-interface')).toBeHidden();
    } else {
      await expect(page.locator('.timeline-demo')).toBeVisible();
      await expect(page.locator('.preview-device')).toBeHidden();
    }
    await expect(page.getByRole('tab', { selected: true })).toHaveCount(1);
  }
  await page.getByRole('tab', { name: 'Timeline', exact: true }).focus();
  await page.keyboard.press('ArrowRight');
  await expect(page.getByRole('tab', { name: 'Moods' })).toBeFocused();
  await page.keyboard.press('End');
  await expect(page.getByRole('tab', { name: 'Time Capsules' })).toHaveAttribute('aria-selected', 'true');
  await page.keyboard.press('ArrowRight');
  await expect(page.getByRole('tab', { name: 'Timeline', exact: true })).toBeFocused();
  await page.keyboard.press('ArrowLeft');
  await expect(page.getByRole('tab', { name: 'Time Capsules' })).toBeFocused();
  await page.keyboard.press('Home');
  await expect(page.getByRole('tab', { name: 'Timeline', exact: true })).toBeFocused();
  await page.getByRole('link', { name: 'Meet Time Capsules' }).click();
  await expect(page.getByRole('tab', { name: 'Time Capsules' })).toHaveAttribute('aria-selected', 'true');
});

test('FAQ answers expand and collapse using the keyboard', async ({ page }) => {
  await page.goto('/');
  await page.keyboard.press('Escape');
  for (const details of await page.locator('.faq-list details').all()) {
    await details.locator('summary').focus();
    await page.keyboard.press('Enter');
    await expect(details).toHaveAttribute('open', '');
    await expect(details.locator('.faq-answer')).toBeVisible();
    await page.keyboard.press('Space');
    await expect(details).not.toHaveAttribute('open');
  }
});

for (const width of [320, 390, 768, 1440]) {
  test(`responsive layout and WCAG checks at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');
    await revealPage(page);
    await page.waitForLoadState('networkidle');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    const scan = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
    expect(scan.violations).toEqual([]);
    await page.screenshot({ path: `qa/landing-${width}.png`, fullPage: true });
  });
}

test('mobile menu opens, closes on navigation, dismisses with Escape and manages focus', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  const toggle = page.getByRole('button', { name: 'Open navigation' });
  const nav = page.getByRole('navigation', { name: 'Main navigation' });
  await expect(nav).toBeHidden();
  await toggle.click();
  await expect(nav).toBeVisible();
  await page.keyboard.press('Tab');
  await expect(nav.getByRole('link', { name: 'Home', exact: true })).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(nav).toBeHidden();
  await expect(toggle).toBeFocused();
  await toggle.click();
  await nav.getByRole('link', { name: 'Features', exact: true }).click();
  await expect(page).toHaveURL(/#features$/);
  await expect(nav).toBeHidden();
  await toggle.click();
  // Scan the final colors, not a partially transparent scroll entrance.
  await page.emulateMedia({ reducedMotion: 'reduce' });
  expect((await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze()).violations).toEqual([]);
});

test('reduced motion removes movement and the page survives 200% text', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  expect(await page.locator('.phone-front').evaluate((element) => getComputedStyle(element).animationName)).toBe('none');
  expect(await page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior)).toBe('auto');
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%'; });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  expect(await page.locator('.card-copy').evaluateAll((cards) => cards.filter((card) => card.getBoundingClientRect().bottom > card.closest('article').getBoundingClientRect().bottom).length)).toBe(0);
  expect(await page.locator('.notes-card .card-copy').evaluate((element) => element.getBoundingClientRect().width)).toBeGreaterThan(300);
  await page.getByRole('button', { name: 'Open navigation' }).click();
  await expect(page.getByRole('navigation', { name: 'Main navigation' })).toBeVisible();
  await page.screenshot({ path: 'qa/text-200-percent.png', fullPage: true });
});

test('content, navigation and FAQs work without JavaScript', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:4173/');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await expect(page.getByRole('navigation', { name: 'Main navigation' })).toBeVisible();
  await expect(page.locator('.preview-tabs')).toBeHidden();
  const first = page.locator('.faq-list details').first();
  await first.locator('summary').click();
  await expect(first.locator('.faq-answer')).toBeVisible();
  await expect(page.getByRole('link', { name: /^Open USpace/ })).toBeVisible();
  await context.close();
});

test('scroll effects follow the page and respect a live reduced-motion change', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  const phone = page.locator('.phone-front');
  const before = await phone.evaluate((el) => getComputedStyle(el).translate);
  await page.evaluate(() => window.scrollTo({ top: 500, behavior: 'instant' }));
  await expect.poll(() => phone.evaluate((el) => getComputedStyle(el).translate)).not.toBe(before);
  await expect(page.locator('.site-header')).toHaveClass(/has-scrolled/);
  await page.locator('#about').scrollIntoViewIfNeeded();
  await expect(page.locator('#main-nav a[href="#about"]')).toHaveAttribute('aria-current', 'location');
  await page.screenshot({ path: 'qa/story-motion.png' });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect.poll(() => phone.evaluate((el) => getComputedStyle(el).translate)).toBe('none');
  await expect.poll(() => page.locator('.ring-left').evaluate((el) => getComputedStyle(el).translate)).toBe('none');
  expect(await page.locator('.reveal-ready').evaluateAll((els) => els.every((el) => getComputedStyle(el).opacity === '1'))).toBe(true);
});

test('mood demo syncs selections, supports keyboard, and never saves or sends the mood', async ({ page }) => {
  const remote = [];
  page.on('request', (request) => { if (!request.url().startsWith('http://127.0.0.1:4173/')) remote.push(request.url()); });
  await page.goto('/');
  const hero = page.locator('.mood-phone');
  await hero.getByRole('button', { name: 'Calm', exact: true }).click();
  await expect(hero.locator('.demo-mood-title')).toHaveText('A softer kind of day.');
  await expect(page.locator('#mood-announcement')).toContainText('Demo mood set to Calm');
  await expect(page.locator('.feature-mood-demo [data-mood="calm"]')).toHaveAttribute('aria-pressed', 'true');
  await hero.getByRole('button', { name: 'Need a hug' }).focus();
  await page.keyboard.press('Enter');
  await expect(hero.locator('.demo-mood-title')).toHaveText('A hug would be nice.');
  await page.getByRole('tab', { name: 'Moods', exact: true }).click();
  await expect(page.locator('.gallery-mood-demo [data-mood="need_a_hug"]')).toHaveAttribute('aria-pressed', 'true');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.locator('.gallery-mood-demo').getByRole('button', { name: 'Loved', exact: true }).click();
  expect(await page.locator('.gallery-mood-demo .demo-mood-image').evaluate((el) => el.getAnimations().length)).toBe(0);
  await page.reload();
  await expect(hero.getByRole('button', { name: 'Loved', exact: true })).toHaveAttribute('aria-pressed', 'true');
  expect(remote).toEqual([]);
  expect(await page.evaluate(() => Object.keys(localStorage))).toEqual([]);
});

test('Timeline supports adding, editing, cancelling, deleting, empty and reset states', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('link', { name: 'Edit the Timeline demo', exact: true }).click();
  const board = page.getByRole('region', { name: 'Editable Timeline demo' });
  const dialog = page.getByRole('dialog');
  await board.getByRole('button', { name: '+ Add memory', exact: true }).click();
  await expect(page.getByLabel('Give it a title')).toBeFocused();
  await page.getByLabel('Give it a title').fill('Our <special> day');
  await page.getByLabel('When was it?').fill('2026-10-09');
  await page.getByLabel('The little details').fill('Coffee and a walk.');
  await page.getByLabel('Choose an illustration').selectOption('night');
  await dialog.getByRole('button', { name: 'Save memory' }).click();
  await expect(board.getByRole('heading', { name: 'Our <special> day', exact: true })).toBeVisible();
  const edit = board.getByRole('button', { name: 'Edit Our <special> day', exact: true });
  await expect(edit).toBeFocused();
  await edit.click();
  await page.getByLabel('Give it a title').fill('A new title');
  await page.keyboard.press('Escape');
  await expect(edit).toBeFocused();
  await edit.click();
  await page.getByLabel('Give it a title').fill('Our favourite day');
  await dialog.getByRole('button', { name: 'Save memory' }).click();
  await expect(board.getByRole('heading', { name: 'Our favourite day', exact: true })).toBeVisible();
  await board.getByRole('button', { name: 'Remove Our favourite day', exact: true }).click();
  await expect(board.locator('.memory-card')).toHaveCount(3);
  while (await board.locator('[data-action="remove"]').count()) await board.locator('[data-action="remove"]').first().click();
  await expect(board.locator('.memory-empty')).toBeVisible();
  await board.getByRole('button', { name: 'Reset demo' }).click();
  await expect(board.locator('.memory-card')).toHaveCount(3);
  await page.setViewportSize({ width: 390, height: 844 });
  await board.getByRole('button', { name: '+ Add memory', exact: true }).click();
  await page.emulateMedia({ reducedMotion: 'reduce' });
  expect((await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze()).violations).toEqual([]);
  await page.screenshot({ path: 'qa/timeline-editor-mobile.png' });
  await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
});

test('intro is the first rendered state, lasts four seconds, and replays only on document navigation', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  await expect(page.locator('#welcome-intro')).toBeVisible();
  await expect(page.locator('main')).toBeHidden();
  expect(await page.locator('#welcome-intro').evaluate(el => el.getAnimations()[0].effect.getTiming().duration)).toBe(4000);
  await page.keyboard.press('Escape');
  await expect(page.locator('#welcome-intro')).toBeHidden();
  await page.getByRole('tab', {name:'Moods',exact:true}).click();
  await expect(page.locator('#welcome-intro')).toBeHidden();
  await page.reload();
  await expect(page.locator('#welcome-intro')).toBeVisible();
  await expect(page.getByRole('button',{name:'Skip intro',exact:true})).toHaveCount(0);
  await page.keyboard.press('Escape');
  await expect(page.locator('main')).toBeVisible();
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.reload();
  await expect(page.locator('#welcome-intro')).toBeHidden();
});

test('capsule opens, reverses mid-flight, reseals repeatedly, and keeps locked content absent', async ({ page }) => {
  test.setTimeout(90000);
  await page.goto('/');
  await page.getByRole('tab', { name: 'Time Capsules', exact: true }).click();
  const envelope = page.getByRole('region', { name: 'Time Capsule envelope demo' });
  const control = envelope.locator('.capsule-toggle');
  const content = envelope.locator('.capsule-interface');
  await expect(content).toBeHidden();
  await control.click();
  await expect(envelope).toHaveAttribute('data-state', 'opening');
  await control.click();
  await expect(envelope).toHaveAttribute('data-state', 'sealed');
  for (let index = 0; index < 2; index++) {
    await control.click();
    await expect(envelope).toHaveAttribute('data-state', 'open', {timeout:8000});
    await expect(envelope.getByRole('button',{name:'Tap the letter to read it'})).toHaveCount(0);
    await expect(envelope.locator('.capsule-interface')).toBeVisible();
    await expect(control).toHaveAttribute('aria-expanded', 'true');
    await expect(content.getByRole('heading', { name: 'Your Time Capsules' })).toBeVisible();
    await expect(content.locator('img')).toHaveJSProperty('complete', true);
    await control.click();
    await expect(envelope).toHaveAttribute('data-state', 'sealed', {timeout:8000});
    await expect(content).toBeHidden();
  }
  await envelope.getByLabel('Explore a demo').selectOption('locked');
  await control.focus();
  await page.keyboard.press('Enter');
  await expect(envelope).toHaveAttribute('data-state', 'open', {timeout:8000});
  await envelope.getByRole('button',{name:'Seal again',exact:true}).click();
  await expect(envelope).toHaveAttribute('data-state','sealing');
  await expect(envelope).toHaveAttribute('data-state','sealed',{timeout:8500});
  await page.emulateMedia({reducedMotion:'reduce'});
  await control.click();
  await expect(content.getByRole('heading', { name: 'Not quite time, my love.' })).toBeVisible();
  await expect(content.locator('.capsule-countdown')).toContainText(/\d+d/);
  await expect(content.locator('img')).toHaveCount(0);
  const release = await content.locator('.capsule-release').textContent();
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await control.click();
  await expect(content).toBeHidden();
  await control.click();
  await expect(envelope).toHaveAttribute('data-state', 'open');
  await expect(content.locator('.capsule-release')).toHaveText(release);
  expect((await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze()).violations).toEqual([]);
  await page.setViewportSize({ width: 390, height: 844 });
  await envelope.scrollIntoViewIfNeeded();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: 'qa/capsule-locked-mobile.png' });
  await page.getByRole('tab', { name: 'Chat', exact: true }).click();
  await page.getByRole('link', { name: 'Explore the Time Capsule envelope' }).click();
  await expect(envelope).toHaveAttribute('data-state', 'sealed');
  await page.getByRole('tab', { name: 'Chat', exact: true }).click();
  await page.locator('.capsule-card h3').click();
  await expect(envelope).toBeVisible();
});

test('hero keeps the following sections below the fold and reveals work in both directions', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.setViewportSize({ width: 1440, height: 1100 });
  await page.goto('/');
  await page.keyboard.press('Escape');
  expect(await page.evaluate(() => window.scrollY)).toBe(0);
  expect(await page.locator('#features').evaluate((el) => el.getBoundingClientRect().top)).toBeGreaterThanOrEqual(1099);
  const card = page.locator('.timeline-card');
  await card.scrollIntoViewIfNeeded();
  await expect(card).toHaveClass(/is-visible/);
  await page.locator('#faq').scrollIntoViewIfNeeded();
  await expect(card).not.toHaveClass(/is-visible/);
  await card.scrollIntoViewIfNeeded();
  await expect(card).toHaveClass(/is-visible/);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  expect(await page.locator('.reveal-ready').evaluateAll((els) => els.every((el) => getComputedStyle(el).opacity === '1'))).toBe(true);
});
