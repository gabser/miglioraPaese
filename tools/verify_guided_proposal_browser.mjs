// Run against an isolated local API and a Flutter web build using that API.
// Tile responses are simulated; no requests are made to a map provider.
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const appUrl = process.env.APP_URL ?? 'http://127.0.0.1:8892';
const evidence = process.env.EVIDENCE_DIR ?? fileURLToPath(new URL('../docs/design/evidence/guided-proposal/', import.meta.url));
mkdirSync(evidence, { recursive: true });
const tile = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP49P3XfwAJpQPjiokzCAAAAABJRU5ErkJggg==', 'base64');
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const results = [];
const enable = async page => {
  await page.waitForTimeout(1800);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.getByRole('heading', { name: /Passaggio/ }).waitFor();
};
async function press(page, locator) {
  // The Flutter semantics scroll surface handles scrollIntoView for offscreen controls.
  await locator.click();
  await page.waitForTimeout(350);
}
async function acknowledge(page) {
  const comparison = page.getByRole('button', { name: /problema diverso.*continua|Continua senza confronto/i });
  if (await comparison.count()) await press(page, comparison.first());
}
try {
  for (const width of [390, 1440]) {
    for (const mode of (process.env.GUIDED_MODES?.split(',') ?? ['success', 'lost', 'malformed', 'tile-error'])) {
      console.log(`Checking ${width} ${mode}`);
      const context = await browser.newContext({ viewport: { width, height: 1000 } });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      let posts = 0, committed, sent, lookups = 0, keyboardEdits = 0;
      await page.route('**/tiles/**', route => mode === 'tile-error'
        ? route.abort('failed') : route.fulfill({ status: 200, contentType: 'image/png', body: tile }));
      await page.route('**/v1/municipalities/tuglie/next-problems', async route => {
        if (route.request().method() !== 'POST') return route.continue();
        posts++;
        sent = route.request().postDataJSON();
        const response = await route.fetch();
        assert.equal(response.status(), 201);
        committed = await response.json();
        if (mode === 'lost') return route.abort('failed');
        if (mode === 'malformed') return route.fulfill({ status: 201, contentType: 'application/json', body: '{broken' });
        return route.fulfill({ response });
      });
      page.on('request', request => { if (request.url().includes('/next-problem-submissions/')) lookups++; });
      await page.goto(`${appUrl}/#/suggest-problem?municipality=tuglie`);
      await enable(page);
      assert.equal(await page.getByRole('checkbox').count(), 13);
      if (mode === 'success') await page.screenshot({ path: join(evidence, `problem-${width}.png`) });
      await press(page, page.getByRole('checkbox', { name: 'Illuminazione', exact: true }));
      await press(page, page.getByRole('radio', { name: 'Lampione spento', exact: true }));
      await press(page, page.getByRole('button', { name: 'Continua', exact: true }));
      await press(page, page.getByRole('button', { name: /^Tipo di luogo/ }));
      await press(page, page.getByLabel('Luogo specifico', { exact: true }).last());
      assert.equal(await page.locator('flt-semantics-host').getByText(/Punto confermato:/).count(), 0);
      const selectCenter = page.getByRole('button', { name: 'Seleziona il centro', exact: true });
      if (mode === 'tile-error') {
        await page.locator('flt-semantics-host').getByText(/Mappa non disponibile/).waitFor();
        assert.equal(await selectCenter.isDisabled(), true);
        await page.getByRole('textbox', { name: 'Nome del luogo', exact: true }).focus();
        await page.waitForTimeout(400);
        await page.keyboard.insertText('Parco delle Rose'); keyboardEdits++;
        await page.waitForTimeout(500);
      } else {
        await selectCenter.waitFor();
        await press(page, selectCenter);
        await press(page, page.getByRole('button', { name: 'Usa questo punto', exact: true }));
        await page.locator('flt-semantics-host').getByText(/Punto confermato:/).waitFor();
        if (mode === 'success') await page.screenshot({ path: join(evidence, `place-${width}.png`) });
      }
      await press(page, page.getByRole('button', { name: 'Continua', exact: true }));
      try { await page.getByText('Riepilogo della proposta', { exact: true }).waitFor({timeout: 5000}); } catch (error) {
        console.log(await page.locator('body').innerText());
        console.log('FIELDS', await page.getByRole('textbox').evaluateAll(els => els.map(el => ({label:el.getAttribute('aria-label'),value:el.value}))));
        await page.screenshot({path:join(evidence, `failure-${width}-${mode}.png`)}); throw error;
      }
      if (mode === 'success') await page.screenshot({ path: join(evidence, `summary-${width}.png`) });
      await acknowledge(page);
      await press(page, page.getByRole('button', { name: 'Invia proposta', exact: true }));
      if (mode === 'lost' || mode === 'malformed') {
        await page.getByRole('button', { name: 'Verifica invio', exact: true }).waitFor();
        await page.reload(); await enable(page);
        await press(page, page.getByRole('button', { name: 'Verifica invio', exact: true }));
      }
      await page.waitForURL(/proposal-receipt/);
      await page.getByRole('heading', { name: 'Invio ricevuto', exact: true }).waitFor();
      assert.equal(posts, 1);
      assert.equal(sent.title, 'Lampione spento');
      assert.ok(sent.description.startsWith('Lampione spento. Luogo: '));
      assert.ok(committed.id && page.url().includes(committed.id));
      if (mode === 'tile-error') {
        assert.equal(sent.location.label, 'Parco delle Rose');
        assert.equal(sent.location.coordinates, undefined);
      } else {
        assert.equal(keyboardEdits, 0);
        assert.equal(sent.location.label, undefined);
        assert.equal(sent.location.kind, 'specific');
        assert.deepEqual(committed.location.coordinates, sent.location.coordinates);
        await page.locator('flt-semantics-host').getByText(/Punto confermato:/).waitFor();
      }
      if (mode === 'success') await page.screenshot({ path: join(evidence, `receipt-${width}.png`) });
      await press(page, page.getByRole('button', { name: 'Apri il dettaglio aggiornato', exact: true }));
      await page.getByRole('button', { name: 'Aggiorna il dettaglio', exact: true }).waitFor();
      if (mode !== 'tile-error') await page.locator('flt-semantics-host').getByText(/Punto confermato:/).waitFor();
      assert.deepEqual(errors, []);
      results.push({ width, mode, posts, lookups, keyboardEdits, receiptId: committed.id,
        coordinates: sent.location.coordinates ?? null, sameCoordinatesInReceipt: mode !== 'tile-error',
        journey: 'Flutter choices → location → summary → POST → receipt → live detail' });
      await context.close();
    }
  }
  writeFileSync(join(evidence, 'results.json'), JSON.stringify({ browser: browser.version(), results,
    limits: 'Headless Chrome, simulated local tiles, isolated SQLite. No live map provider, physical device or human screen reader test.' }, null, 2) + '\n');
  console.log(JSON.stringify({ passed: results.length, results }));
} finally { await browser.close(); }
