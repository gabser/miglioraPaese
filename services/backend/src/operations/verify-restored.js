import {createAccountService} from '../application/account-service.js';
import {createSimulatedEmailAdapter} from '../infrastructure/simulated-email.js';
import {createMissionRepository} from '../persistence/postgres/mission-repository.js';
import {createReviewRepository} from '../persistence/postgres/review-repository.js';
import {createMeasurementRepository} from '../persistence/postgres/measurement-repository.js';
import {createCooperationService} from '../application/cooperation-service.js';
export async function verifyRestoredDependencies({pool,fantasy,configuration}){
 const flags=configuration?.features;if(!flags||configuration.persistence!=='postgres')throw Error('Restore requires identified PostgreSQL feature configuration.');
 const checks={fantasy:()=>fantasy.isReady(),persistence:async()=>{await pool.query('SELECT token_hash FROM proposal_sessions LIMIT 0');return true;}};
 if(flags.accounts)checks.accounts=()=>createAccountService({pool,emailAdapter:createSimulatedEmailAdapter()}).isReady();
 if(flags.missions)checks.missions=()=>createMissionRepository(pool).ready();
 if(flags.review)checks.review=()=>createReviewRepository(pool).ready();
 if(flags.measurements)checks.measurements=()=>createMeasurementRepository(pool).ready();
 if(flags.cooperation)checks.cooperation=()=>createCooperationService({pool,fantasy}).isReady();
 for(const check of Object.values(checks))if(!await check())throw Error('Restored configured dependency is not ready.');
 return true;
}
