import { AsyncLocalStorage } from 'node:async_hooks';
import { withTransaction } from './transaction.js';
// One client per pool and asynchronous call chain. Raw SQL and fantasy operations
// join this boundary; pool size one is supported without a nested lock waiter.
const contexts=new WeakMap();
export function unitOfWork(pool){
 if(contexts.has(pool))return contexts.get(pool);
 const context=new AsyncLocalStorage();
 const api={client:()=>context.getStore(),run:action=>context.getStore()?action(context.getStore()):withTransaction(pool,async c=>{
  await c.query('SELECT pg_advisory_xact_lock(76131001)');return context.run(c,()=>action(c));
 },{logger:{warn(){},error(){}}})};contexts.set(pool,api);return api;
}
