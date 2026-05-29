import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repo = 'cemalyilmaz/unit-testing-catalog';
const imagePath = path.resolve(__dirname, '../assets/social-preview-github.jpg');
const settingsUrl = `https://github.com/${repo}/settings`;
const authStatePath = path.resolve(__dirname, '../.github/playwright-auth.json');

async function ensureLoggedIn(page) {
  await page.goto(settingsUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  if (!page.url().includes('/login')) return;

  console.log('Sign in to GitHub in the browser window…');
  await page.goto('https://github.com/login', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(
    () => !!document.querySelector('meta[name="user-login"]')?.content?.trim(),
    null,
    { timeout: 300000 },
  );
  await page.goto(settingsUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  if (page.url().includes('/login')) {
    throw new Error('Still not logged in after sign-in.');
  }
}

async function upload(page) {
  const socialHeading = page.locator("xpath=//h2[normalize-space()='Social preview']").first();
  await socialHeading.waitFor({ state: 'attached', timeout: 60000 });
  await socialHeading.scrollIntoViewIfNeeded();

  const editButton = page.locator('#edit-social-preview-button');
  const socialEditButton = page.locator(
    "xpath=(//h2[normalize-space()='Social preview']/following::*[(self::button or self::summary) and normalize-space(.)='Edit'][1])",
  );
  const fileInput = page.locator('input#repo-image-file-input');
  const uploadMenuItem = page.getByText(/upload an image/i).first();
  const imageIdInput = page.locator('input.js-repository-image-id');

  if (await editButton.count()) {
    await editButton.first().click({ force: true }).catch(() => {});
  } else if (await socialEditButton.count()) {
    await socialEditButton.first().click({ force: true }).catch(() => {});
  }

  await Promise.any([
    fileInput.first().waitFor({ state: 'attached', timeout: 30000 }),
    uploadMenuItem.waitFor({ state: 'visible', timeout: 30000 }),
  ]);

  const uploadResponsePromise = page
    .waitForResponse(
      (resp) => {
        const u = resp.url();
        return (
          resp.status() >= 200 &&
          resp.status() < 300 &&
          (u.includes('/upload/repository-images/') ||
            u.includes('/upload/policies/repository-images'))
        );
      },
      { timeout: 30000 },
    )
    .catch(() => null);

  if (await fileInput.count()) {
    await fileInput.first().setInputFiles(imagePath);
  } else {
    const [chooser] = await Promise.all([
      page.waitForEvent('filechooser'),
      uploadMenuItem.click({ force: true }),
    ]);
    await chooser.setFiles(imagePath);
  }

  await uploadResponsePromise;
  await page.waitForFunction(() => {
    const input = document.querySelector('input.js-repository-image-id');
    return !!((input?.value || '').trim());
  }, { timeout: 30000 });

  const newId = await imageIdInput.first().inputValue();
  console.log(`Uploaded. Image id: ${newId.trim()}`);
}

async function main() {
  const browser = await chromium.launch({ headless: false, channel: 'chrome' });
  const contextOptions = fs.existsSync(authStatePath)
    ? { storageState: authStatePath }
    : {};
  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();

  try {
    await ensureLoggedIn(page);
    await upload(page);
    fs.mkdirSync(path.dirname(authStatePath), { recursive: true });
    await context.storageState({ path: authStatePath });
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
