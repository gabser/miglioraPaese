import {lstat,mkdir,realpath,readFile,writeFile,rename,open} from 'node:fs/promises';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
export async function privateDirectory(root,{create=false}={}) {
 if(typeof root!=='string'||!path.isAbsolute(root)||root==='/'||path.normalize(root)!==root)throw Error('Absolute normalized private directory required.');
 // Refuse symlinks in every existing ancestor, including the root itself.
 let cursor=path.parse(root).root;
 for(const part of root.split(path.sep).filter(Boolean)){cursor=path.join(cursor,part);try{const stat=await lstat(cursor);if(stat.isSymbolicLink()||!stat.isDirectory())throw Error('Unsafe private directory.');}catch(e){if(e.code!=='ENOENT')throw e;if(!create)throw e;await mkdir(cursor,{mode:0o700});}}
 const stat=await lstat(root);if((stat.mode&0o077)!==0)throw Error('Private directory must have mode 700.');
 if(await realpath(root)!==root)throw Error('Unsafe private directory.');
 return root;
}
export async function privateRead(file,maxBytes=16*1024*1024){const stat=await lstat(file);if(!stat.isFile()||stat.isSymbolicLink()||(stat.mode&0o077)!==0||stat.size>maxBytes)throw Error('Unsafe private file.');const handle=await open(file,'r');try{const actual=await handle.stat();if(actual.ino!==stat.ino||actual.dev!==stat.dev)throw Error('Private file changed.');return await handle.readFile();}finally{await handle.close();}}
export async function privateWrite(file,bytes){const temp=file+'.'+randomUUID();await writeFile(temp,bytes,{flag:'wx',mode:0o600});const handle=await open(temp,'r');try{await handle.sync();}finally{await handle.close();}await rename(temp,file);const parent=await open(path.dirname(file),'r');try{await parent.sync();}finally{await parent.close();}}
export function testDatabase(connectionString){let url;try{url=new URL(connectionString);}catch{throw Error('Explicit synthetic loopback test database required.');}if(!['postgres:','postgresql:'].includes(url.protocol)||!['127.0.0.1','localhost','[::1]'].includes(url.hostname)||!/^\/[a-z][a-z0-9_]{0,57}_test$/.test(url.pathname)||url.search||url.hash)throw Error('Explicit synthetic loopback test database required.');return url;}
export function disposableDatabase(connectionString){const url=testDatabase(connectionString);if(!/^\/sentinelle_restore_[a-z0-9_]{1,30}_test$/.test(url.pathname))throw Error('New disposable restore database required.');return url;}
