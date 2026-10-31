import {mkdir,readFile,writeFile,unlink,lstat,open} from 'node:fs/promises';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {constants as fsConstants} from 'node:fs';
import {privateDirectory} from '../operations/private-files.js';
export const proofKeyPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export function createLocalProofStorage({root}={}){
 if(process.platform==='darwin'&&typeof root==='string'){if(root.startsWith('/var/'))root='/private'+root;else if(root.startsWith('/tmp/'))root='/private'+root;}
 if(typeof root!=='string'||!path.isAbsolute(root)||root==='/')throw new TypeError('Explicit absolute local proof storage root is required.');
 const file=key=>{if(typeof key!=='string'||!proofKeyPattern.test(key))throw new TypeError('Invalid private proof key.');return path.join(root,key);};
 const safe=async key=>{await privateDirectory(root,{create:true});const location=file(key);try{const stat=await lstat(location);if(!stat.isFile()||stat.isSymbolicLink())throw Error('Unsafe private proof.');}catch(e){if(e.code!=='ENOENT')throw e;}return location;};
 return {kind:'local-synthetic',
  async put(bytes){await privateDirectory(root,{create:true});const key=randomUUID();await writeFile(file(key),bytes,{flag:'wx',mode:0o600});return key;},
  async get(key){const location=await safe(key);const handle=await open(location,fsConstants.O_RDONLY|fsConstants.O_NOFOLLOW);try{return await handle.readFile();}finally{await handle.close();}},
  async delete(key){try{await unlink(await safe(key));}catch(e){if(e.code!=='ENOENT')throw e;}},
 };
}
