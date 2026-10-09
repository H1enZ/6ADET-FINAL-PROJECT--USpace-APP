/** Captures the real Flutter UI from the loopback-only fixture server.
 * Run after the isolated build; see CAPTURE.md. Never logs request bodies,
 * authentication responses, browser storage, passwords, or session values.
 */
import { chromium } from '@playwright/test';
import { mkdir } from 'node:fs/promises';

const output = new URL('../qa/captures/', import.meta.url);
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ channel: 'chromium' });
try {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, timezoneId: 'Asia/Manila' });
  await context.route('**/*', (route) => {
    const host = new URL(route.request().url()).hostname;
    return ['127.0.0.1', 'fonts.gstatic.com', 'fonts.googleapis.com'].includes(host) ? route.continue() : route.abort();
  });
  const page = await context.newPage();
  await page.clock.setFixedTime(new Date('2026-10-09T01:00:00Z'));
  await page.goto('http://127.0.0.1:54329/');
  await page.waitForTimeout(10000);
  const save = async (name) => {
    await page.waitForTimeout(1400);
    await page.screenshot({ path: new URL(`${name}.png`, output).pathname.replace(/^\/(\w:)/, '$1') });
    console.log(`Captured ${name} from the local Flutter renderer.`);
  };
  await save('home-ashley');
  await page.mouse.click(118, 810);
  await save('chat-demo');
  await page.mouse.click(272, 810);
  await save('notes-demo');
  await page.mouse.click(195, 185);
  await save('capsules-demo');
  await page.mouse.click(28, 30);
  await page.mouse.click(38, 810);
  await page.mouse.click(195, 550);
  await save('moods-demo');
  await context.close();
} finally { await browser.close(); }
