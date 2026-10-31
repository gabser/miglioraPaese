import { fantasyStatements } from './fantasy-statements.js';
import { AsyncLocalStorage } from 'node:async_hooks';
import { unitOfWork } from './unit-of-work.js';
import { sessionHash, sessionRevoked, sessionIdentity } from '../../domain/proposal-session.js';

// The pilot serializes fantasy transactions across processes. This deliberately
// favors consistent roster/market/league invariants over write throughput.
const fantasyLock = 76131001;
export function createFantasyRepository(pool, { onTransactionCheckpoint = async () => {}, clock=Date.now } = {}) {
  if (!pool?.connect) throw new TypeError('Fantasy requires a PostgreSQL pool.');
  const uow=unitOfWork(pool);
  const scopes=new AsyncLocalStorage();
  let beforeAction=async()=>{};
  const authorization = new AsyncLocalStorage();
  const pending = new WeakMap();
  async function query(operation, args) {
    const sql=fantasyStatements[operation];
    if(!sql)throw new TypeError('Unknown fantasy persistence operation: '+operation);
    let index = 0;
    const statement = sql.replaceAll('?', () => '$' + (++index));
    const client=uow.client();
    const previous=client?pending.get(client):null;
    const queryPromise=(previous??Promise.resolve()).then(()=> (client??pool).query(statement,args));
    if(client)pending.set(client,queryPromise.catch(()=>{}));
    const result=await queryPromise;
    return result.rows;
  }
  const repository = {
    async one(sql, ...args) { return (await query(sql, args))[0]; },
    many: (sql, ...args) => query(sql, args),
    execute: (sql, ...args) => query(sql, args),
    raw: (sql,args=[]) => (uow.client()??pool).query(sql,args),
    scoped: (seasonId,action) => scopes.run(seasonId??null,action),
    seasonHint: () => scopes.getStore()??null,
    setBeforeAction: hook=>{beforeAction=hook;},
    authenticated: (token, action, principal=null) => authorization.run({tokenHash:sessionHash(token),principal}, action),
    async transaction(action) {
      if (uow.client()) return action();
      return uow.run(async (client) => {

        const authorizationContext = authorization.getStore();
        const tokenHash=authorizationContext?.tokenHash;
        if (tokenHash) {
          await onTransactionCheckpoint('before_session_lock');
          // Revocation takes FOR UPDATE on the same row. Its completion is a
          // barrier: commands that subsequently obtain this lock are rejected.
          const result = await client.query(
            'SELECT revoked_at,account_id,submission_scope,expires_at FROM public.proposal_sessions WHERE token_hash = $1 FOR SHARE', [tokenHash]);
          if (!result.rows[0] || result.rows[0].revoked_at !== null) throw sessionRevoked();
          const row=result.rows[0];
          if(row.expires_at&&Date.parse(row.expires_at)<=clock())throw Object.assign(new Error('Session has expired.'),{statusCode:401,code:'session_expired'});
          if(authorizationContext.principal!==null && authorizationContext.principal!==sessionIdentity({submissionScope:row.submission_scope,accountId:row.account_id}))throw Object.assign(new Error('Session identity changed. Reload.'),{statusCode:409,code:'identity_changed'});
          await onTransactionCheckpoint('session_locked');
        }
        await beforeAction(client);
        const result=await action();
        if(tokenHash){const row=(await client.query('SELECT revoked_at,expires_at FROM proposal_sessions WHERE token_hash=$1',[tokenHash])).rows[0];if(!row||row.revoked_at)throw sessionRevoked();if(row.expires_at&&Date.parse(row.expires_at)<=clock())throw Object.assign(new Error('Session expired.'),{statusCode:401,code:'session_expired'});}
        return result;
      });
    },
  };
  return repository;
}
export const transaction = (repository, action) => repository.transaction(action);
