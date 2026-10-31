import {readFile,stat} from 'node:fs/promises';
import pg from 'pg';
import {publishSyntheticCalendar} from '../src/application/calendar-publication.js';
const [flag,file,...extras]=process.argv.slice(2),url=new URL(process.env.DATABASE_URL??'');
if(flag!=='--local-synthetic'||!file||extras.length||!['127.0.0.1','localhost','[::1]'].includes(url.hostname)||!url.pathname.endsWith('_test'))throw new TypeError('Use --local-synthetic file.json with a loopback *_test database.');
if((await stat(file)).size>262144)throw new TypeError('Calendar exceeds 256 KiB.');
const input=JSON.parse(await readFile(file,'utf8')),pool=new pg.Pool({connectionString:url.href,max:1});
try{console.log(JSON.stringify(await publishSyntheticCalendar({pool,input,loopbackSynthetic:true})));}finally{await pool.end();}
