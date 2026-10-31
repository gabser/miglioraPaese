import {restoredExposureReady} from './operations/restore-marker.js';
import {runtimeIdentity,createRequestObserver} from './operations/diagnostics.js';
import {createErasureJournal} from './operations/erasure-journal.js';
import {testDatabase} from './operations/private-files.js';
import {createCooperationService} from './application/cooperation-service.js';
import {createCooperationEvents} from './application/cooperation-events.js';
import {createMeasurementService} from './application/measurement-service.js';
import {createMeasurementRepository} from './persistence/postgres/measurement-repository.js';
import { createReviewService } from './application/review-service.js';
import { createReviewRepository } from './persistence/postgres/review-repository.js';
import { createMissionService } from './application/mission-service.js';
import { createMissionRepository } from './persistence/postgres/mission-repository.js';
import { createLocalProofStorage } from './infrastructure/local-proof-storage.js';
import { createAccountService } from './application/account-service.js';
import { createSimulatedEmailAdapter } from './infrastructure/simulated-email.js';
import { createRemoteGameService } from './application/remote-game-service.js';
import { createRemoteGameRepository } from './persistence/postgres/remote-game-repository.js';
import { createFantasyStore } from './application/fantasy/store.js';
import http from 'node:http';

import { loadServerConfig } from './config/environment.js';
import { createApp } from './http/app.js';
import { createMemoryStore } from './infrastructure/memory-store.js';
import { createPostgresPool } from './persistence/postgres/pool.js';
import { createPostgresStore } from './persistence/postgres/postgres-store.js';

export {
  createApp,
  createMemoryStore,
  createPostgresPool,
  createPostgresStore,
};

export function startServer(options = {}) {
  const logger = options.logger ?? console;
  const config = loadServerConfig({
    env: options.env ?? process.env,
    port: options.port,
    host: options.host,
    allowedOrigins: options.allowedOrigins,
    dataStore: options.dataStore,
  });
  const environment=options.env??process.env;
  if(environment.FANTASY_ENABLED!==undefined && !['true','false'].includes(environment.FANTASY_ENABLED))throw new TypeError('FANTASY_ENABLED must be true or false.');
  if(environment.FANTASY_ENABLED==='true' && config.dataStore!=='postgres')throw new TypeError('Fantasy requires PostgreSQL.');
  if(environment.ACCOUNT_ENABLED!==undefined&&!['true','false'].includes(environment.ACCOUNT_ENABLED))throw new TypeError('ACCOUNT_ENABLED must be true or false.');
  if(environment.ACCOUNT_ENABLED==='true'&&(config.dataStore!=='postgres'||environment.EMAIL_DELIVERY!=='simulated'))throw new TypeError('Account requires PostgreSQL and explicit EMAIL_DELIVERY=simulated.');
  if(environment.MISSIONS_ENABLED!==undefined&&!['true','false'].includes(environment.MISSIONS_ENABLED))throw new TypeError('MISSIONS_ENABLED must be true or false.');
  if(environment.MISSIONS_ENABLED==='true'&&(config.dataStore!=='postgres'||environment.ACCOUNT_ENABLED!=='true'||environment.MISSION_STORAGE!=='local-synthetic'||!environment.MISSION_STORAGE_ROOT||!Number.isInteger(Number(environment.MISSION_RETENTION_DAYS))))throw new TypeError('Missions require PostgreSQL accounts and explicit local synthetic storage/retention.');
  if(environment.MISSIONS_ENABLED==='true'){
    createLocalProofStorage({root:environment.MISSION_STORAGE_ROOT});
    const retention=Number(environment.MISSION_RETENTION_DAYS);if(retention<1||retention>30)throw new TypeError('MISSION_RETENTION_DAYS must be 1–30.');
  }
  if(environment.REVIEW_ENABLED!==undefined&&!['true','false'].includes(environment.REVIEW_ENABLED))throw new TypeError('REVIEW_ENABLED must be true or false.');
  if(environment.REVIEW_ENABLED==='true'&&(environment.MISSIONS_ENABLED!=='true'||environment.ACCOUNT_ENABLED!=='true'||config.dataStore!=='postgres'))throw new TypeError('Review requires PostgreSQL accounts and missions.');
  if(environment.MEASUREMENTS_ENABLED!==undefined&&!['true','false'].includes(environment.MEASUREMENTS_ENABLED))throw new TypeError('MEASUREMENTS_ENABLED must be true or false.');
  if(environment.MEASUREMENTS_ENABLED==='true'&&(config.dataStore!=='postgres'||['ACCOUNT_ENABLED','MISSIONS_ENABLED','REVIEW_ENABLED','FANTASY_ENABLED'].some(k=>environment[k]!=='true')))throw new TypeError('Measurements require PostgreSQL, accounts, missions, review and fantasy.');
  if(environment.LEAGUE_CONTINUITY_ENABLED!==undefined&&!['true','false'].includes(environment.LEAGUE_CONTINUITY_ENABLED))throw new TypeError('LEAGUE_CONTINUITY_ENABLED must be true or false.');
  if(environment.LEAGUE_CONTINUITY_ENABLED==='true'&&(config.dataStore!=='postgres'||environment.FANTASY_ENABLED!=='true'))throw new TypeError('League continuity requires PostgreSQL fantasy.');
  if(environment.COOPERATION_ENABLED!==undefined&&!['true','false'].includes(environment.COOPERATION_ENABLED))throw new TypeError('COOPERATION_ENABLED must be true or false.');
  if(environment.COOPERATION_ENABLED==='true'&&(config.dataStore!=='postgres'||['ACCOUNT_ENABLED','MISSIONS_ENABLED','REVIEW_ENABLED','MEASUREMENTS_ENABLED','FANTASY_ENABLED'].some(k=>environment[k]!=='true')))throw new TypeError('Cooperation requires PostgreSQL accounts, missions, review, measurements and fantasy.');
  const identity=runtimeIdentity(environment,config.dataStore);
  if(environment.OPS_LOCAL_ENABLED!==undefined&&!['true','false'].includes(environment.OPS_LOCAL_ENABLED))throw new TypeError('OPS_LOCAL_ENABLED must be true or false.');
  if(identity.features.opsLocal){if(config.dataStore!=='postgres'||!['127.0.0.1','localhost','::1'].includes(config.host)||environment.FANTASY_ENABLED!=='true'||!environment.OPS_JOURNAL_ROOT)throw new TypeError('Local operations require explicit synthetic loopback PostgreSQL fantasy and journal.');testDatabase(config.postgres.connectionString);}
  const observer=options.observer??createRequestObserver({logger:options.requestLogger??logger,candidateId:identity.candidateId});
  const runtime = createRuntimeStore(config, options);
  const journal=identity.features.opsLocal?createErasureJournal({root:environment.OPS_JOURNAL_ROOT}):null;
  journal?.catch(()=>{});
  const ops=journal?{isReady:async()=>{try{return await (await journal).isReady();}catch{return false;}},erase:async(...args)=>(await journal).erase(...args)}:undefined;
  const server = http.createServer(
    createApp({
      store: runtime.store,
      identity,observer,ops,exposureReady:runtime.exposureReady,
      allowedOrigins: config.allowedOrigins,
      fantasy: runtime.fantasy ?? options.fantasy,
      remoteGame: runtime.remoteGame ?? options.remoteGame,
      readiness:runtime.readiness ?? options.readiness,
      cooperation:runtime.cooperation??options.cooperation,
      measurements:runtime.measurements??options.measurements,
      review:runtime.review ?? options.review,
      missions:runtime.missions ?? options.missions,
      accounts:runtime.accounts ?? options.accounts,
      leagueContinuityEnabled: environment.LEAGUE_CONTINUITY_ENABLED==='true',
      adminToken: (options.env ?? process.env).FANTASY_ADMIN_TOKEN,
      pilotMunicipalityId: (options.env ?? process.env).FANTASY_PILOT_MUNICIPALITY,
    }),
  );
  let closingResources;
  const closeResources = () => {
    closingResources ??= Promise.resolve().then(runtime.close);
    return closingResources;
  };
  const closeResourcesSafely = () => {
    void closeResources().catch((error) => {
      logger.error?.('Backend resources failed to close.', {
        code: 'resource_close_failed',
      });
    });
  };
  Object.defineProperty(server, 'closeResources', {
    value: closeResources,
    enumerable: false,
  });
  server.once('close', () => {
    closeResourcesSafely();
  });
  server.once('error', () => {
    closeResourcesSafely();
  });
  server.listen(config.port, config.host);
  return server;
}

function createRuntimeStore(config, options) {
  if (options.store) {
    return {
      store: options.store,
      close: options.closeStore ?? (() => {}),
    };
  }
  if (config.dataStore === 'memory') {
    return { store: createMemoryStore(), close: () => {} };
  }

  const pool = options.pool ?? createPostgresPool(config.postgres, {
    logger: options.logger,
  });
  const exposureReady=()=>restoredExposureReady(pool,options.env??process.env);
  const exposureGate=exposureReady().then(ready=>{if(!ready)throw Error('Restored copy requires verification.');});exposureGate.catch(()=>{});
  const env=options.env??process.env;
  const cooperationEvents=env.COOPERATION_ENABLED==='true'?createCooperationEvents({clock:options.now}):undefined;
  const fantasy=env.FANTASY_ENABLED==='true'?exposureGate.then(()=>createFantasyStore({pool,now:options.now,seedDemo:env.FANTASY_DEMO_SEED==='true',cooperationEvents})):undefined;
  // Observe startup errors immediately; requests still receive the same failure.
  fantasy?.catch(error=>options.logger?.error?.('Fantasy initialization failed.',{code:'initialization_failed'}));
  const missionRepository=env.MISSIONS_ENABLED==='true'?createMissionRepository(pool,{clock:options.now}):null;
  const missions=missionRepository?(async()=>{await exposureGate;if(env.MISSIONS_DEMO_SEED==='true')await missionRepository.seed();return createMissionService({repository:missionRepository,storage:options.proofStorage??createLocalProofStorage({root:env.MISSION_STORAGE_ROOT}),clock:options.now,cooperationEvents,retentionDays:Number(env.MISSION_RETENTION_DAYS)});})():undefined;
  missions?.catch(error=>options.logger?.error?.('Mission initialization failed.',{code:'initialization_failed'}));
  const review=env.REVIEW_ENABLED==='true'?createReviewService({repository:createReviewRepository(pool,{clock:options.now}),storage:options.proofStorage??createLocalProofStorage({root:env.MISSION_STORAGE_ROOT}),clock:options.now,cooperationEvents,retentionDays:Number(env.MISSION_RETENTION_DAYS)}):undefined;
  const measurements=env.MEASUREMENTS_ENABLED==='true'?(async()=>createMeasurementService({repository:createMeasurementRepository(pool,{clock:options.now}),fantasy:await fantasy,storage:options.proofStorage??createLocalProofStorage({root:env.MISSION_STORAGE_ROOT}),clock:options.now,cooperationEvents}))():undefined;
  measurements?.catch(error=>options.logger?.error?.('Measurements initialization failed.',{code:'initialization_failed'}));
  const cooperation=cooperationEvents?(async()=>createCooperationService({pool,fantasy:await fantasy,clock:options.now}))():undefined;
  cooperation?.catch(error=>options.logger?.error?.('Cooperation initialization failed.',{code:'initialization_failed'}));
  return {
    exposureReady,
    cooperation,
    measurements,
    review,
    missions,
    fantasy,
    accounts:env.ACCOUNT_ENABLED==='true'?createAccountService({pool,clock:options.now,emailAdapter:options.emailAdapter??createSimulatedEmailAdapter()}):undefined,
    readiness:async()=>{if(!await exposureReady())return false;await pool.query('SELECT token_hash FROM public.proposal_sessions LIMIT 0');return true;},
    remoteGame:createRemoteGameService({repository:createRemoteGameRepository(pool,{clock:options.now})}),
    store: createPostgresStore(pool, { logger: options.logger,clock:options.now }),
    close: () => pool.end(),
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = startServer();
  server.once('listening', () => {
    const address = server.address();
    const location =
      typeof address === 'string'
        ? address
        : 'http://' + address.address + ':' + address.port;
    console.log('Backend listening on ' + location);
  });
  server.once('error', (error) => {
    console.error('Backend failed to start:', error.message);
    process.exitCode = 1;
  });
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.once(signal, () => {
      server.close((error) => {
        if (error) {
          console.error('Backend failed to stop:', error.message);
          process.exitCode = 1;
        }
      });
    });
  }
}
