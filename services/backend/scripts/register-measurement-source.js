import {readFile} from 'node:fs/promises';
import pg from 'pg';
import {registerSyntheticMeasurementSource} from '../src/persistence/postgres/measurement-synthetic-fixture.js';
const [flag,file]=process.argv.slice(2),url=new URL(process.env.DATABASE_URL??'');
if(flag!=='--local-synthetic'||!file||!['127.0.0.1','localhost','[::1]'].includes(url.hostname)||!url.pathname.endsWith('_test'))throw new TypeError('Use --local-synthetic file.json with a loopback *_test database.');
const pool=new pg.Pool({connectionString:url.href,max:1});try{const source=JSON.parse(await readFile(file,'utf8'));await registerSyntheticMeasurementSource({pool,source,loopbackSynthetic:true});console.log('Synthetic source registered; no operational ratification.');}finally{await pool.end();}
