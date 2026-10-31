import path from 'node:path';
import {randomBytes,randomUUID,createHmac,createHash,timingSafeEqual} from 'node:crypto';
import {writeFile,mkdir,rmdir,lstat} from 'node:fs/promises';
import {privateDirectory,privateRead,privateWrite} from './private-files.js';
const digest=(key,value)=>createHmac('sha256',key).update(value).digest('hex');
export async function createErasureJournal({root,initialize=false,onCheckpoint=async()=>{}}){
 await privateDirectory(root,{create:initialize});
 const keyFile=path.join(root,'journal.key'),journalFile=path.join(root,'journal.json'),lock=path.join(root,'journal.lock');
 let newJournal=false;
 if(initialize){const exists=async file=>{try{await lstat(file);return true;}catch(e){if(e.code==='ENOENT')return false;throw e;}};const hasKey=await exists(keyFile),hasJournal=await exists(journalFile);if(hasKey!==hasJournal)throw Error('Incomplete existing erasure journal. Recover the original external files.');newJournal=!hasKey;if(newJournal)await writeFile(keyFile,randomBytes(32),{mode:0o600,flag:'wx'});}
 const key=await privateRead(keyFile,32);if(key.length!==32)throw Error('Invalid journal key.');
 const sign=data=>({data,mac:digest(key,JSON.stringify(data))});
 if(newJournal){try{await writeFile(journalFile,JSON.stringify(sign({version:1,id:randomUUID(),entries:[]})),{mode:0o600,flag:'wx'});}catch(e){if(e.code!=='EEXIST')throw e;}}
 async function read(){const currentKey=await privateRead(keyFile,32);if(currentKey.length!==key.length||!timingSafeEqual(currentKey,key))throw Error('External journal key unavailable or changed.');const parsed=JSON.parse(await privateRead(journalFile));const mac=digest(key,JSON.stringify(parsed.data));if(typeof parsed.mac!=='string'||parsed.mac.length!==64||!timingSafeEqual(Buffer.from(mac),Buffer.from(parsed.mac)))throw Error('Invalid erasure journal integrity.');const d=parsed.data;if(d.version!==1||!Array.isArray(d.entries)||d.entries.length>100000||typeof d.id!=='string'||d.entries.some((e,i)=>!e||e.sequence!==i+1||!/^([0-9a-f]{64})$/.test(e.ref)||!['pending','complete'].includes(e.state)))throw Error('Invalid erasure journal.');return d;}
 let tail=Promise.resolve();
 async function exclusive(action){const result=tail.then(async()=>{await mkdir(lock,{mode:0o700});try{return await action();}finally{await rmdir(lock);}});tail=result.catch(()=>{});return result;}
 const journal={
  root,
  signMarker:data=>digest(key,'restore:'+JSON.stringify(data)),
  verifyMarker:(data,mac)=>typeof mac==='string'&&mac.length===64&&timingSafeEqual(Buffer.from(digest(key,'restore:'+JSON.stringify(data))),Buffer.from(mac)),
  signManifest:data=>digest(key,'snapshot:'+JSON.stringify(data)),
  verifyManifest:(data,mac)=>typeof mac==='string'&&mac.length===64&&timingSafeEqual(Buffer.from(digest(key,'snapshot:'+JSON.stringify(data))),Buffer.from(mac)),
  ref:principal=>digest(key,'fantasy:'+principal),
  keyFingerprint:createHash('sha256').update(key).digest('hex'),
  read,
  withSnapshot:action=>exclusive(async()=>action(await journal.assertReady())),
  async isReady(){try{return (await read()).entries.every(e=>e.state==='complete');}catch{return false;}},
  async assertReady(){const data=await read();if(data.entries.some(e=>e.state!=='complete'))throw Error('Pending erasure requires reconciliation.');return data;},
  async erase(principal,action){return exclusive(async()=>{const data=await read(),ref=journal.ref(principal);let entry=data.entries.find(e=>e.ref===ref&&e.state==='pending');if(!entry){entry={ref,state:'pending',sequence:data.entries.length+1};data.entries.push(entry);}else entry.state='pending';await privateWrite(journalFile,JSON.stringify(sign(data)));await onCheckpoint('erasure_pending');const result=await action();await onCheckpoint('erasure_db_committed');entry.state='complete';await privateWrite(journalFile,JSON.stringify(sign(data)));return result;});},
  async replay({pool,fantasy,expectedId,expectedKeyFingerprint,watermark,onCheckpoint=async()=>{}}){const data=await journal.assertReady();if(data.id!==expectedId||journal.keyFingerprint!==expectedKeyFingerprint)throw Error('Restore requires the original external erasure journal.');if(!Number.isInteger(watermark)||watermark<0||watermark>data.entries.length)throw Error('Invalid journal snapshot watermark.');const rows=await pool.query("SELECT DISTINCT 'account:'||id::text AS principal FROM accounts UNION SELECT DISTINCT 'session:'||submission_scope::text FROM proposal_sessions UNION SELECT user_id FROM fantasy_players");let erased=0;for(const row of rows.rows)if(data.entries.some(e=>e.sequence>watermark&&e.ref===journal.ref(row.principal))){await onCheckpoint('restore_erasure_before');await fantasy.eraseUserData(row.principal);erased++;await onCheckpoint('restore_erasure_applied');}return {erased,journalId:data.id};},
 };
 await read();return journal;
}
