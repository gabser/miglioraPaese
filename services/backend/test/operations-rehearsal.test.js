import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {integrationTest} from './helpers/fantasy.js';
import {rehearseOperations} from '../scripts/rehearse-operations.js';
integrationTest('cohesive two-week synthetic PostgreSQL HTTP operations rehearsal with restore exposure gate',async()=>{
 await rehearseOperations({databaseUrl:process.env.TEST_DATABASE_URL,candidateId:'c'.repeat(64),artifactRoot:fileURLToPath(new URL('../../../.sentinelle-local/phase8/backend',import.meta.url))});
});
