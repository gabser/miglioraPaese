import 'dart:js_interop';
import 'invite_link.dart' show inviteFromFragment;

@JS('window.location.href')
external JSString get _href;
@JS('document.baseURI')
external JSString get _base;
@JS('window.history.replaceState')
external void _replace(JSAny? state, JSString title, JSString url);
String? captureLeagueInvite() {
  final location = Uri.parse(_href.toDart);
  if (!location.fragment.startsWith('league-invite=')) return null;
  final token = inviteFromFragment(location.fragment);
  // Remove even malformed invitations. Never send a token to router/telemetry.
  _replace(null, ''.toJS, location.replace(fragment: '').toString().toJS);
  return token;
}

Uri appBase() {
  final base = Uri.parse(_base.toDart), location = Uri.parse(_href.toDart);
  return base.origin == location.origin ? base : location.resolve('.');
}
