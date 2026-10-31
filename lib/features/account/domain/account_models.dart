class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.pseudonym,
    required this.email,
  });
  final String id, pseudonym, email;
  factory AccountProfile.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['pseudonym'] is! String ||
        raw['email'] is! String ||
        raw['emailVerified'] != true) {
      throw const FormatException('Invalid verified account');
    }
    return AccountProfile(
      id: raw['id'] as String,
      pseudonym: raw['pseudonym'] as String,
      email: raw['email'] as String,
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'pseudonym': pseudonym,
    'email': email,
    'emailVerified': true,
  };
}

class AccountChallenge {
  const AccountChallenge({
    required this.id,
    required this.expiresAt,
    required this.retryAfterSeconds,
  });
  final String id;
  final DateTime expiresAt;
  final int retryAfterSeconds;
}

class AccountDevice {
  const AccountDevice({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isCurrent,
    this.revokedAt,
  });
  final String id, name;
  final DateTime createdAt;
  final bool isCurrent;
  final DateTime? revokedAt;
}

class GuestLinkConflict {
  const GuestLinkConflict({
    required this.seasonId,
    required this.municipalityId,
  });
  final String seasonId, municipalityId;
}

class GuestLinkResult {
  const GuestLinkResult({required this.linked, required this.conflicts});
  final bool linked;
  final List<GuestLinkConflict> conflicts;
}
