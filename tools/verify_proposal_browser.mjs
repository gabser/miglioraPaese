import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const evidenceDir = process.env.EVIDENCE_DIR ?? fileURLToPath(
  new URL('../docs/design/evidence/', import.meta.url),
);
const appUrl = process.env.APP_URL ?? 'http://127.0.0.1:8899';
const apiUrl = process.env.API_BASE_URL ?? 'http://127.0.0.1:8787';
mkdirSync(evidenceDir, { recursive: true });

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const results = [];
const emptyStates = [];

async function enableSemantics(page) {
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(700);
}

async function enterText(page, label, text) {
  await page.getByRole('textbox', { name: label, exact: true }).focus();
  // Flutter creates its editing element after focus; paste once it is ready.
  await page.waitForTimeout(400);
  await page.keyboard.insertText(text);
  await page.waitForTimeout(350);
}

try {
  for (const width of [390, 1440]) {
    for (const failure of ['lost', 'malformed']) {
      const context = await browser.newContext({ viewport: { width, height: 900 } });
      const page = await context.newPage();
      let posts = 0;
      let committed;
      let sent;
      let lookups = 0;

      await page.route('**/v1/municipalities/tuglie/next-problems', async (route) => {
        if (route.request().method() !== 'POST') return route.continue();
        posts++;
        sent = route.request().postDataJSON();
        const response = await route.fetch();
        assert.equal(response.status(), 201, 'SQLite must commit before the response fault');
        committed = await response.json();
        if (failure === 'lost') {
          await route.abort('failed');
        } else {
          await route.fulfill({ status: 201, contentType: 'application/json', body: '{broken' });
        }
      });
      page.on('request', (request) => {
        if (request.url().includes('/next-problem-submissions/')) lookups++;
      });

      await page.goto(`${appUrl}/#/suggest-problem?municipality=tuglie`);
      await page.waitForTimeout(3500);
      await enableSemantics(page);
      // Avoid numeric sequences that the pilot correctly moderates as phone numbers.
      const title = `Alberi lungo il percorso ${failure} ${crypto.randomUUID().replace(/[0-9-]/g, '')}`;
      await page.getByRole('checkbox', { name: 'Verde pubblico', exact: true }).click();
      await page.getByRole('radio', { name: 'Il mio caso è diverso', exact: true }).click();
      await enterText(page, 'Descrivi brevemente il tuo caso',
        'I rami coprono il passaggio e devono essere osservati nel Comune.');
      await page.getByRole('button', { name: 'Continua', exact: true }).click();
      await page.getByRole('button', { name: /^Tipo di luogo/ }).click();
      await page.getByLabel('Intero Comune', { exact: true }).last().click();
      await page.getByRole('button', { name: 'Continua', exact: true }).click();
      await enterText(page, 'Titolo del problema', title);
      await page.getByRole('button', { name: 'Controlla la proposta', exact: true }).click();
      await page.waitForTimeout(700);
      const comparison = page.getByRole('button', {
        name: /problema diverso.*continua|Continua senza confronto/,
      });
      if (await comparison.count()) await comparison.first().click();
      await page.getByRole('button', { name: 'Invia proposta', exact: true }).click();
      await page.getByRole('button', { name: 'Verifica invio', exact: true }).waitFor();
      assert.ok(committed, 'The submission must already exist in SQLite');
      await page.mouse.move(width * 0.6, 400);
      await page.mouse.wheel(0, -5000);
      await page.waitForTimeout(500);
      await page.screenshot({ path: join(evidenceDir, `ui-${failure}-uncertain-${width}.png`) });

      await page.reload();
      await page.waitForTimeout(3500);
      await enableSemantics(page);
      const lookupResponse = page.waitForResponse((response) =>
        response.url().includes('/next-problem-submissions/') && response.request().method() === 'GET');
      await page.getByRole('button', { name: 'Verifica invio', exact: true }).click();
      const lookup = await (await lookupResponse).json();
      assert.deepEqual(lookup.receipt, committed, 'The lookup must return the immutable original receipt');
      assert.equal(lookup.submissionScope, sent.expectedSubmissionScope);
      await page.waitForURL(/proposal-receipt/);
      await page.waitForTimeout(1500);
      assert.ok(page.url().includes(committed.id), 'The UI route must show the committed ID');
      assert.ok((await page.locator('body').innerText()).includes(title));
      await page.screenshot({ path: join(evidenceDir, `ui-${failure}-receipt-${width}.png`) });
      await page.getByRole('button', { name: 'Apri il dettaglio aggiornato', exact: true }).click();
      await page.waitForTimeout(1300);
      await page.screenshot({ path: join(evidenceDir, `ui-${failure}-detail-${width}.png`) });
      // Read-only corroboration after the actual UI journey, not a substitute for it.
      const own = await page.evaluate(async (api) =>
        await (await fetch(`${api}/v1/municipalities/tuglie/next-problems?own=true`,
          { credentials: 'include' })).json(), apiUrl);
      assert.equal(posts, 1);
      assert.equal(own.items.length, 1);
      assert.equal(own.items[0].id, committed.id);
      assert.ok(lookups >= 1);
      assert.ok((await context.cookies()).some((cookie) => cookie.httpOnly));
      results.push({ width, failure, postCount: posts, lookupCount: lookups,
        oneProposal: true, sameReceipt: true, sameScope: true, httpOnly: true,
        receiptId: committed.id,
        path: 'Flutter form → committed response fault → reload → UI lookup → receipt → live detail' });
      await context.close();
    }

    const context = await browser.newContext({ viewport: { width, height: 900 } });
    const page = await context.newPage();
    await page.route('**/v1/municipalities/tuglie/next-problems*', async (route) => {
      assert.equal(route.request().method(), 'GET');
      const response = await route.fetch();
      const data = await response.json();
      await route.fulfill({ response, body: JSON.stringify({ ...data, items: [] }) });
    });
    await page.goto(`${appUrl}/#/next-problems?municipality=tuglie`);
    await page.waitForTimeout(3500);
    await enableSemantics(page);
    const emptyText = await page.locator('body').innerText();
    assert.match(emptyText, /nessuna proposta/i);
    assert.doesNotMatch(emptyText, /Comune in attivazione/i);
    await page.screenshot({ path: join(evidenceDir, `ui-empty-proposals-${width}.png`) });
    emptyStates.push({ width, fixture: 'GET list items=[] in browser; SQLite unchanged' });
    await context.close();
  }
  writeFileSync(join(evidenceDir, 'browser-ui-recovery.json'), JSON.stringify({
    applicationRevision: process.env.REVIEW_REVISION ?? 'working tree',
    browser: browser.version(), results, emptyStates,
    limit: 'Headless Chrome viewport; no physical device or human usability test.',
  }, null, 2) + '\n');
  console.log(JSON.stringify({ cases: results.length, results, emptyStates }));
} finally {
  await browser.close();
}
