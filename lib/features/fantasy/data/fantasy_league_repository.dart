import 'package:fanta_comune/features/fantasy/data/fantasy_api_mapper.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';

class RemoteFantasyLeague {
  const RemoteFantasyLeague({
    required this.table,
    required this.memberCount,
    required this.competitiveCount,
    required this.isOwner,
    required this.isSpectator,
    required this.archived,
    required this.firstLocksAt,
  });
  final FantasyLeague table;
  final int memberCount;
  final int competitiveCount;
  final bool isOwner;
  final bool isSpectator;
  final bool archived;
  final DateTime firstLocksAt;
  static RemoteFantasyLeague fromJson(Map<String, dynamic> raw) {
    final l = FantasyApiMapper.object(raw['league']);
    final role = l['role'], status = l['status'];
    if (!['competitor', 'spectator'].contains(role) ||
        !['active', 'archived'].contains(status) ||
        l['minimumParticipants'] != 3) {
      throw const FormatException('Invalid league metadata');
    }
    final entries = (raw['entries'] as List).map((v) {
      final row = FantasyApiMapper.object(v);
      return LeagueEntry(
        userId: row['memberId'] as String,
        displayName: row['pseudonym'] as String,
        points: row['points'] as int,
        rank: row['rank'] as int,
        isCurrentUser: row['isCurrentUser'] as bool,
      );
    }).toList();
    return RemoteFantasyLeague(
      table: FantasyLeague(
        id: l['id'] as String,
        name: l['name'] as String,
        entries: List.unmodifiable(entries),
        isMunicipal: false,
        minimumParticipants: 3,
      ),
      memberCount: l['memberCount'] as int,
      competitiveCount: l['competitiveCount'] as int,
      isOwner: l['isOwner'] as bool,
      isSpectator: role == 'spectator',
      archived: status == 'archived',
      firstLocksAt: FantasyApiMapper.date(l['firstLocksAt']),
    );
  }
}

class FantasyLeagueInvite {
  const FantasyLeagueInvite({
    required this.id,
    required this.token,
    required this.expiresAt,
  });
  final String id;
  final String token;
  final DateTime expiresAt;
}

abstract interface class FantasyLeagueRepository {
  Future<List<RemoteFantasyLeague>> loadLeagues();
  Future<void> createLeague(String name);
  Future<void> joinLeague(String token);
  Future<void> leaveLeague(String id);
  Future<FantasyLeagueInvite> rotateInvite(String id);
  Future<void> revokeInvite(String leagueId, String inviteId);
}
