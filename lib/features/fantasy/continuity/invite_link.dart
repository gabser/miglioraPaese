import 'invite_link_stub.dart'
    if (dart.library.js_interop) 'invite_link_web.dart'
    as platform;

/// Capture synchronously, before preferences, router, or any HTTP request.
String? captureLeagueInvite() => platform.captureLeagueInvite();
Uri leagueInviteLink(String token, {Uri? base}) {
  if (!validInviteToken(token))
    throw const FormatException('Invito non valido.');
  final origin = (base ?? platform.appBase()).resolve('.');
  return origin.replace(query: null, fragment: 'league-invite=$token');
}

bool validInviteToken(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value);
String? inviteFromFragment(String fragment) {
  if (!fragment.startsWith('league-invite=')) return null;
  final token = fragment.substring('league-invite='.length);
  return validInviteToken(token) ? token : null;
}
