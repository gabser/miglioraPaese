import pg from 'pg';
import { it } from 'node:test';
import { Readable } from 'node:stream';
import { createApp, createPostgresStore } from '../../src/server.js';
import { createFantasyStore } from '../../src/application/fantasy/store.js';
import { runPostgresMigrations } from '../../src/persistence/postgres/migrator.js';
export function integrationTest(name, callback) {
  const scoring=name.startsWith('matches all 48');
  return it(name,{skip:!scoring&&!process.env.TEST_DATABASE_URL?'TEST_DATABASE_URL is not configured.':false},callback);
}
const quiet={debug(){},info(){},warn(){},error(){}};
export async function createTestStore(options={}) {
  const databaseUrl=options.databaseUrl??process.env.TEST_DATABASE_URL;
  if(options.seedStartsAt!==undefined && !/(?:Z|[+-]\d{2}:\d{2})$/.test(options.seedStartsAt))throw new TypeError('seedStartsAt requires timezone.');
  if(!databaseUrl) throw new Error('Fantasy integration requires TEST_DATABASE_URL.');
  const url=new URL(databaseUrl);
  if(!url.pathname.endsWith('_test')||!['127.0.0.1','localhost','[::1]'].includes(url.hostname))throw new Error('Disposable loopback test database required.');
  const pool=new pg.Pool({connectionString:databaseUrl,max:options.poolMax??8});
  await runPostgresMigrations({databaseUrl,attestationDatabaseUrl:databaseUrl,sourceCommit:'fantasy-integration',artifactDigest:'sha256:'+'a'.repeat(64),logger:quiet});
  await pool.query('TRUNCATE fantasy_seasons, fantasy_invite_preview_attempts CASCADE');
  const fantasy=await createFantasyStore({pool,now:options.now,seedStartsAt:options.seedStartsAt,seedDemo:true});
  const store=createPostgresStore(pool,{logger:quiet,clock:options.now});
  Object.assign(store,{fantasy,pool,close:()=>pool.end(),deleteUserData:userId=>fantasy.eraseUserData(userId)});
  return store;
}
export async function createTestFantasy(options={}) {
  const store=await createTestStore(options);
  return {...store.fantasy,close:()=>store.close()};
}
export function client(app) {
  let tokenPromise;
  async function invoke(path,method='GET',body,headers={}) {
    const req=Readable.from(body===undefined?[]:[Buffer.from(JSON.stringify(body))]);
    Object.assign(req,{url:path,method,headers});
    const res={writeHead(status,headers){this.status=status;this.headers=headers;},end(payload){this.body=JSON.parse(payload);}};
    await app(req,res);return res;
  }
  return async(path,method='GET',body)=>{
    tokenPromise??=invoke('/v1/proposal-session','POST',{}).then(res=>res.body.token);
    const token=await tokenPromise;
    return invoke(path,method,body,{authorization:'Bearer '+token});
  };
}
export function appFor(store,options={}) {return createApp({store,fantasy:store.fantasy,...options});}
