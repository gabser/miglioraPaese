import { createHash, randomUUID } from 'node:crypto';
import { exactFields, fantasyError } from './teams.js';

export function migrateFantasyMarket(database) {
  database.exec(`
    CREATE TABLE fantasy_quotes (
      id TEXT PRIMARY KEY,
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (json_valid(payload)),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    ) STRICT;
    CREATE TABLE fantasy_transfer_commands (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      command_key TEXT NOT NULL,
      request_hash TEXT NOT NULL,
      response TEXT NOT NULL CHECK (json_valid(response)),
      PRIMARY KEY (season_id, user_id, command_key),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE
    ) STRICT;
    CREATE TABLE fantasy_transfers (
      id TEXT PRIMARY KEY,
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      command_key TEXT NOT NULL,
      cost INTEGER NOT NULL CHECK (cost IN (0, 4)),
      payload TEXT NOT NULL CHECK (json_valid(payload)),
      UNIQUE (season_id, user_id, command_key),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    ) STRICT;
  `);
}

export function marketSchemaReady(database) {
  database.prepare('SELECT id, season_id, user_id, matchday_id, payload FROM fantasy_quotes LIMIT 1').get();
  database.prepare('SELECT season_id, user_id, command_key, request_hash, response FROM fantasy_transfer_commands LIMIT 1').get();
  database.prepare('SELECT id, season_id, user_id, matchday_id, command_key, cost, payload FROM fantasy_transfers LIMIT 1').get();
}

export function transferPenalty(database, player, day) {
  return database.prepare('SELECT COALESCE(SUM(cost), 0) AS cost FROM fantasy_transfers WHERE season_id = ? AND user_id = ? AND matchday_id = ?')
    .get(player.season_id, player.user_id, day.id).cost;
}

export function transferData(database, player, day) {
  const transfers = database.prepare('SELECT payload FROM fantasy_transfers WHERE season_id = ? AND user_id = ? ORDER BY rowid')
    .all(player.season_id, player.user_id).map((row) => JSON.parse(row.payload));
  const count = transfers.filter((t) => t.matchdayId === day.id).length;
  return { transfers, transferPenalty: transferPenalty(database, player, day), transfersRemaining: Math.max(0, 2 - count), nextTransferPenalty: count < 2 ? 0 : 4 };
}

export function createFantasyMarket({ database, teams, now = Date.now }) {
  function fail(code, message, status = 409) { throw fantasyError(status, code, message); }
  function calculate(context, outgoingId, incomingId) {
    const { player, day, cards, squad } = context;
    if (!squad.includes(outgoingId) || squad.includes(incomingId) || !cards.has(incomingId)) fail('invalid_transfer', 'Invalid outgoing or incoming card.', 400);
    const incoming = cards.get(incomingId), outgoing = cards.get(outgoingId);
    if (incoming.availability !== 'available' || incoming.sourceStatus === 'unavailable') fail('card_unavailable', 'Incoming card or source is unavailable.', 400);
    const nextSquad = squad.map((id) => id === outgoingId ? incomingId : id);
    if (!teams.validSquad(nextSquad, cards)) fail('invalid_squad', 'Transfer would violate budget or squad roles.', 400);
    const current = transferData(database, player, day);
    return { outgoingId, incomingId, outgoingPrice: outgoing.price, incomingPrice: incoming.price,
      outgoingRole: outgoing.role, incomingRole: incoming.role, outgoingVersion: outgoing.version, incomingVersion: incoming.version,
      creditDelta: outgoing.price - incoming.price, budgetAfter: 100 - nextSquad.reduce((sum, id) => sum + cards.get(id).price, 0),
      penalty: current.nextTransferPenalty, nextSquad };
  }
  return {
    quote(municipalityId, userId, body) {
      exactFields(body, ['expectedRevision', 'matchdayId', 'outgoingId', 'incomingId']);
      return teams.withOpenTeam(municipalityId, userId, body.expectedRevision, body.matchdayId, (context) => {
        const { season, player, day, time } = context;
        const { nextSquad, ...calculation } = calculate(context, body.outgoingId, body.incomingId);
        const quote = { id: randomUUID(), seasonId: season.id, matchdayId: day.id, expectedRevision: player.revision,
          catalogVersion: season.catalog_version, ...calculation,
          expiresAt: new Date(Math.min(Date.parse(day.locks_at), Date.parse(time) + 5 * 60 * 1000)).toISOString() };
        database.prepare('INSERT INTO fantasy_quotes VALUES (?, ?, ?, ?, ?)').run(quote.id, season.id, userId, day.id, JSON.stringify(quote));
        return { serverTime: time, isDemo: Boolean(season.is_demo), quote };
      });
    },
    confirm(municipalityId, userId, body) {
      exactFields(body, ['quoteId', 'idempotencyKey', 'expectedRevision']);
      if (typeof body.quoteId !== 'string' || typeof body.idempotencyKey !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(body.idempotencyKey) || !Number.isSafeInteger(body.expectedRevision) || body.expectedRevision < 1) {
        fail('invalid_field', 'quoteId, expectedRevision and a valid idempotencyKey are required.', 400);
      }
      const season = teams.seasonFor(municipalityId);
      const fingerprint = createHash('sha256').update(JSON.stringify([body.quoteId, body.expectedRevision])).digest('hex');
      const stored = database.prepare('SELECT request_hash, response FROM fantasy_transfer_commands WHERE season_id = ? AND user_id = ? AND command_key = ?').get(season.id, userId, body.idempotencyKey);
      if (stored) {
        if (stored.request_hash !== fingerprint) fail('idempotency_conflict', 'Idempotency key was used for another payload.');
        return JSON.parse(stored.response);
      }
      const row = database.prepare('SELECT payload FROM fantasy_quotes WHERE id = ? AND season_id = ? AND user_id = ?').get(body.quoteId, season.id, userId);
      if (!row) fail('not_found', 'Transfer quote not found.', 404);
      const quote = JSON.parse(row.payload);
      return teams.withOpenTeam(municipalityId, userId, body.expectedRevision, quote.matchdayId, (context) => {
        const { player, day, time, draft } = context;
        if (body.expectedRevision !== quote.expectedRevision) fail('stale_quote', 'Quote revision is obsolete.');
        if (time >= quote.expiresAt) fail('quote_expired', 'Transfer quote has expired.');
        if (context.season.catalog_version !== quote.catalogVersion) fail('stale_quote', 'Catalog version has changed.');
        const calculated = calculate(context, quote.outgoingId, quote.incomingId);
        for (const field of ['outgoingPrice', 'incomingPrice', 'outgoingRole', 'incomingRole', 'outgoingVersion', 'incomingVersion', 'creditDelta', 'budgetAfter', 'penalty']) {
          if (calculated[field] !== quote[field]) fail('stale_quote', 'Transfer price, budget or penalty has changed.');
        }
        const next = { ...draft, starterIds: draft.starterIds.map((id) => id === quote.outgoingId ? quote.incomingId : id),
          captainId: draft.captainId === quote.outgoingId ? quote.incomingId : draft.captainId,
          predictions: { ...draft.predictions }, motivations: { ...draft.motivations }, confirmed: false };
        delete next.predictions[quote.outgoingId]; delete next.motivations[quote.outgoingId];
        const transfer = { id: randomUUID(), matchdayId: day.id, outgoingCardId: quote.outgoingId,
          incomingCardId: quote.incomingId, createdAt: time, cost: calculated.penalty,
          outgoingPrice: calculated.outgoingPrice, incomingPrice: calculated.incomingPrice, creditDelta: calculated.creditDelta };
        database.prepare('INSERT INTO fantasy_transfers VALUES (?, ?, ?, ?, ?, ?, ?)')
          .run(transfer.id, player.season_id, userId, day.id, body.idempotencyKey, transfer.cost, JSON.stringify(transfer));
        teams.writeDraft(player, day, next);
        database.prepare('UPDATE fantasy_players SET squad_ids = ?, revision = revision + 1 WHERE season_id = ? AND user_id = ?')
          .run(JSON.stringify(calculated.nextSquad), player.season_id, userId);
        const response = teams.view(context.season, teams.playerFor(player.season_id, userId), day, time);
        database.prepare('INSERT INTO fantasy_transfer_commands VALUES (?, ?, ?, ?, ?)')
          .run(player.season_id, userId, body.idempotencyKey, fingerprint, JSON.stringify(response));
        return response;
      });
    },
  };
}
