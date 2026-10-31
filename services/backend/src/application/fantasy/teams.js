import { createHash } from 'node:crypto';
import { transaction } from '../../persistence/postgres/fantasy-repository.js';

const initialSquad = ['buche-centro', 'bus-stazione', 'parco-nord', 'rifiuti-mercato', 'lampioni-sud', 'attraversamenti-scuole', 'alberi-viale', 'sportello-anagrafe'];
const roles = ['mobility', 'environment', 'servicesAndSafety'];
const trends = ['improves', 'stable', 'worsens'];



export function fantasyError(statusCode, code, message) {
  return Object.assign(new Error(message), { statusCode, code });
}
function requireValue(valid, message) {
  if (!valid) throw fantasyError(400, 'invalid_field', message);
}
export function exactFields(body, fields) {
  requireValue(body && typeof body === 'object' && !Array.isArray(body) && Object.keys(body).every((key) => fields.includes(key)), 'Unsupported command field.');
}

export function createFantasyTeams({ database, now = Date.now, catalog, getTransferPenalty = () => 0, getTransferData = () => ({}) }) {
  const isoNow = () => new Date(now()).toISOString();
  const seasonFor = async (municipalityId,explicit=database.seasonHint()) => {
    const rows=(await database.raw('SELECT * FROM fantasy_seasons WHERE municipality_id=$1',[municipalityId])).rows;
    if(explicit!==null&&explicit!==undefined){const row=rows.find(s=>s.id===explicit);return row??missing();}
    const at=now();
    return rows.filter(s=>Date.parse(s.starts_at)<=at&&Date.parse(s.ends_at)>at).sort((a,b)=>Date.parse(b.starts_at)-Date.parse(a.starts_at))[0]
      ??rows.filter(s=>Date.parse(s.starts_at)>at).sort((a,b)=>Date.parse(a.starts_at)-Date.parse(b.starts_at))[0]
      ??rows.sort((a,b)=>Date.parse(b.ends_at)-Date.parse(a.ends_at))[0]??missing();
  };
  const playerFor = async (seasonId, userId) => (await database.one("select_players_by_season_id_user_id", seasonId, userId))
    ?? missing('Season enrollment required.');
  const daysFor = async (seasonId) => (await database.many("select_matchdays_by_season_id", seasonId));
  function missing(message = 'Fantasy resource not found.') { throw fantasyError(404, 'not_found', message); }
  async function dayFor(seasonId, matchdayId, time) {
    const days = (await daysFor(seasonId));
    return (matchdayId ? days.find((d) => d.id === matchdayId) : days.find((d) => Date.parse(d.observation_ends_at) > Date.parse(time)) ?? days.at(-1)) ?? missing();
  }
  async function cardsFor(season) { return new Map((await database.scoped(season.id,()=>catalog(season.municipality_id))).items.map((card) => [card.id, card])); }
  function validSquad(ids, cards) {
    return Array.isArray(ids) && ids.length === 8 && new Set(ids).size === 8 && ids.every((id) => typeof id === 'string' && cards.has(id))
      && ids.reduce((sum, id) => sum + cards.get(id).price, 0) <= 100
      && roles.every((role) => ids.filter((id) => cards.get(id).role === role).length >= 2);
  }
  function validLineup(draft, squad, cards) {
    return Array.isArray(draft.starterIds) && draft.starterIds.length === 5 && new Set(draft.starterIds).size === 5
      && draft.starterIds.every((id) => squad.includes(id)) && draft.starterIds.includes(draft.captainId)
      && roles.every((role) => draft.starterIds.some((id) => cards.get(id).role === role));
  }
  function defaultDraft(player, cards) {
    const squad = JSON.parse(player.squad_ids);
    const starters = roles.map((role) => squad.find((id) => cards.get(id).role === role));
    for (const id of squad) { if (starters.length < 5 && !starters.includes(id)) starters.push(id); }
    return { starterIds: starters, captainId: starters[0], confirmed: false, predictions: {}, motivations: {} };
  }
  async function draftFor(player, day, cards) {
    const row = (await database.one("select_drafts_by_season_id_user_id_matchday_id", player.season_id, player.user_id, day.id));
    return row ? JSON.parse(row.payload) : defaultDraft(player, cards);
  }
  async function writeDraft(player, day, draft) {
    (await database.execute("insert_drafts", player.season_id, player.user_id, day.id, JSON.stringify(draft)));
  }
  async function reconcileInside(time) {
    for (const player of (await database.many("select_players"))) {
      const season = (await database.one("select_seasons_by_id", player.season_id));
      const cards = (await cardsFor(season));
      for (const day of (await daysFor(player.season_id))) {
        if (Date.parse(time) < Date.parse(day.locks_at) || Date.parse(player.created_at) >= Date.parse(day.observation_ends_at)) continue;
        const exists = (await database.one("select_snapshots_by_season_id_user_id_matchday_id", player.season_id, player.user_id, day.id));
        if (exists) continue;
        const squad = JSON.parse(player.squad_ids);
        const draft = (await draftFor(player, day, cards));
        const snapshot = { matchdayId: day.id, seasonId: season.id, rulesVersion: day.rules_version, catalogVersion: season.catalog_version,
          locksAt: day.locks_at, observationEndsAt: day.observation_ends_at,
          squadIds: squad, ...draft, transferPenalty: await getTransferPenalty(player, day),
          eligible: Date.parse(player.created_at) < Date.parse(day.locks_at) && draft.confirmed && validSquad(squad, cards) && validLineup(draft, squad, cards) };
        (await database.execute("insert_snapshots", player.season_id, player.user_id, day.id, JSON.stringify(snapshot)));
      }
    }
  }
  async function reconcile() { return (await transaction(database, async () => (await reconcileInside(isoNow())))); }
  async function view(season, player, day, time) {
    const cards = (await cardsFor(season));
    const squad = JSON.parse(player.squad_ids);
    const draft = (await draftFor(player, day, cards));
    const snapshots = (await database.many("select_snapshots_by_season_id_user_id", season.id, player.user_id)).map((row) => JSON.parse(row.payload));
    return { serverTime: time, isDemo: Boolean(season.is_demo), seasonId: season.id, matchdayId: day.id, revision: player.revision, sessionScope: createHash('sha256').update(JSON.stringify([season.id, player.user_id])).digest('hex'),
      ...(await getTransferData(player, day)), team: { squadIds: squad, ...draft, budgetRemaining: 100 - squad.reduce((sum, id) => sum + cards.get(id).price, 0) }, snapshots };
  }
  function checkRevision(player, revision) {
    requireValue(Number.isSafeInteger(revision) && revision > 0, 'expectedRevision must be a positive integer.');
    if (player.revision !== revision) throw fantasyError(409, 'stale_revision', 'Team revision has changed. Reload before retrying.');
  }
  async function assertOpen(day, time, player) {
    const frozen = (await database.one("select_snapshots_by_season_id_user_id_matchday_id", player.season_id, player.user_id, day.id));
    if (frozen) throw fantasyError(409, 'matchday_locked', 'Matchday is already frozen.');
    if (Date.parse(time) >= Date.parse(day.locks_at)) throw fantasyError(409, 'matchday_locked', 'Matchday is locked.');
    if (Date.parse(time) < Date.parse(day.starts_at)) throw fantasyError(409, 'matchday_not_open', 'Matchday has not started.');
  }
  async function withOpenTeam(municipalityId, userId, revision, matchdayId, action) {
    requireValue(typeof matchdayId === 'string' && matchdayId.length > 0, 'matchdayId is required.');
    (await reconcile());
    return (await transaction(database, async () => {
      const time = isoNow();
      const season = (await seasonFor(municipalityId));
      const player = (await playerFor(season.id, userId));
      const day = (await dayFor(season.id, matchdayId, time));
      checkRevision(player, revision);
      (await assertOpen(day, time, player));
      const cards = (await cardsFor(season));
      return action({ season, player, day, time, cards, squad: JSON.parse(player.squad_ids), draft: (await draftFor(player, day, cards)) });
    }));
  }

  async function mutate(municipalityId, userId, body, confirm) {
    // Reconcile in its own committed transaction: a rejected late command must
    // still leave the last accepted formation frozen.
    (await reconcile());
    return (await transaction(database, async () => {
      const time = isoNow();
      exactFields(body, confirm ? ['expectedRevision', 'matchdayId'] : ['expectedRevision', 'matchdayId', 'starterIds', 'captainId', 'predictions', 'motivations']);
      requireValue(typeof body.matchdayId === 'string', 'matchdayId is required.');
      const season = (await seasonFor(municipalityId));
      const player = (await playerFor(season.id, userId));
      const day = (await dayFor(season.id, body.matchdayId, time));
      checkRevision(player, body.expectedRevision);
      (await assertOpen(day, time, player)); // Checked using server time inside the write transaction.
      const cards = (await cardsFor(season));
      const squad = JSON.parse(player.squad_ids);
      const previous = (await draftFor(player, day, cards));
      const draft = confirm ? { ...previous, confirmed: true } : { ...previous,
        starterIds: body.starterIds, captainId: body.captainId, predictions: body.predictions, motivations: body.motivations };
      requireValue(validSquad(squad, cards) && validLineup(draft, squad, cards), 'Invalid squad, roles, captain or lineup.');
      for (const [field, values] of [['predictions', trends], ['motivations', null]]) {
        const map = draft[field];
        requireValue(map && typeof map === 'object' && !Array.isArray(map) && Object.keys(map).every((id) => draft.starterIds.includes(id)), `${field} must contain only starter card IDs.`);
        for (const value of Object.values(map)) requireValue(values ? values.includes(value) : typeof value === 'string' && value.length <= 1000, `Invalid ${field} value.`);
      }
      if (!confirm && (JSON.stringify(previous.starterIds) !== JSON.stringify(draft.starterIds) || previous.captainId !== draft.captainId)) draft.confirmed = false;
      (await writeDraft(player, day, draft));
      (await database.execute("update_players_by_season_id_user_id", season.id, userId));
      return (await view(season, (await playerFor(season.id, userId)), day, time));
    }));
  }
  const api = {
    async enroll(municipalityId, userId, body) {
      exactFields(body, ['squadIds']);
      (await reconcile());
      return (await transaction(database, async () => {
        const time = isoNow();
        const season = (await seasonFor(municipalityId));
        const day = (await dayFor(season.id, null, time));
        let player = (await database.one("select_players_by_season_id_user_id", season.id, userId));
        if (!player) {
          if (Date.parse(time) >= Date.parse(season.ends_at)) throw fantasyError(409, 'season_ended', 'Season has ended.');
          const cards = (await cardsFor(season));
          const defaultSquad=()=>{
            if(initialSquad.every(id=>cards.has(id)))return initialSquad;
            const available=[...cards.values()].filter(c=>c.availability==='available'&&c.sourceStatus!=='unavailable').sort((a,b)=>a.price-b.price||a.id.localeCompare(b.id));
            const selected=roles.flatMap(role=>available.filter(c=>c.role===role).slice(0,2));
            for(const card of available)if(selected.length<8&&!selected.includes(card))selected.push(card);
            return selected.map(c=>c.id);
          };
          const ids = body.squadIds ?? defaultSquad();
          requireValue(validSquad(ids, cards), 'Squad requires eight unique cards, roles and a budget of 100 credits.');
          requireValue(ids.every((id) => cards.get(id).availability === 'available' && cards.get(id).sourceStatus !== 'unavailable'), 'A squad card is unavailable.');
          (await database.execute("insert_players", season.id, userId, JSON.stringify(ids), time));
          player = (await playerFor(season.id, userId));
          (await writeDraft(player, day, defaultDraft(player, cards)));
          (await reconcileInside(time));
        }
        return (await view(season, player, day, time));
      }));
    },
    async team(municipalityId, userId, matchdayId = null) {
      (await reconcile());
      return transaction(database, async () => {
      const time = isoNow();
      const season = (await seasonFor(municipalityId));
      return (await view(season, (await playerFor(season.id, userId)), (await dayFor(season.id, matchdayId, time)), time));
      });
    },
    update: async (municipalityId, userId, body) => (await mutate(municipalityId, userId, body, false)),
    confirm: async (municipalityId, userId, body) => (await mutate(municipalityId, userId, body, true)),
    withOpenTeam, seasonFor, playerFor, dayFor, validSquad, writeDraft, view,
    reconcile,
    async erase(userId) { (await database.execute("delete_players_by_user_id", userId)); },
  };

  return api;
}
