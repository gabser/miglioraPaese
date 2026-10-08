// Isolated test process. Clock/publishing controls exist only on stdin.
import { createInterface } from 'node:readline';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { createPersistentStore, startServer } from '../../services/backend/src/server.js';
const directory = mkdtempSync(join(tmpdir(),'fantasy-flutter-'));
let time = Date.parse('2026-10-08T00:00:00Z'), store, server;
async function start() {
  store = createPersistentStore({databasePath:join(directory,'state.sqlite'),now:()=>time});
  server = startServer({port:0,store,identitySecret:'isolated-fixture-secret-at-least-32-chars',moderationAdminToken:'isolated-fixture-admin-at-least-32-chars'});
  await once(server,'listening');
  return {url:`http://127.0.0.1:${server.address().port}`};
}
async function close() { await new Promise(resolve=>server.close(resolve)); store.close(); }
console.log(JSON.stringify(await start()));
for await (const line of createInterface({input:process.stdin})) {
  try {
    const command=JSON.parse(line);
    if(command.action==='clock') time=Date.parse(command.value);
    if(command.action==='publish') {
      for(const card of store.fantasy.cards('tuglie').items.filter(c=>c.sourceStatus==='verified')) {
        store.fantasy.results.publish('tuglie','matchday-1',card.id,{observed:'stable',sourceLabel:card.sourceLabel,
          sourceDate:'2026-10-15T00:00:00Z',sourceStatus:'verified',explanation:'Fixture sintetica',rulesVersion:'fantasy-demo-v1',version:1});
      }
    }
    if(command.action==='restart') { await close(); console.log(JSON.stringify(await start())); continue; }
    if(command.action==='stop') { await close(); rmSync(directory,{recursive:true,force:true}); break; }
    console.log(JSON.stringify({ok:true}));
  } catch(error) { console.log(JSON.stringify({error:error.message})); }
}
