import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/session_lease_source.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'account_session_store.dart';

/// Competitive data follows the account. Proposal recovery keeps the guest lease.
class AuthenticatedSessionSource extends ChangeNotifier
    implements SessionLeaseSource {
  AuthenticatedSessionSource({required this.guest, required this.account}) {
    account.addListener(_changed);
  }
  final ProposalSessionStore guest;
  final AccountSessionStore account;
  int _generation = 0;
  final Map<String, ({bool account, ProposalSessionLease lease})> _leases = {};
  void _changed() {
    _generation++;
    _leases.clear();
    notifyListeners();
  }

  @override
  bool get preservesCompetitiveDataOnReset => account.hasCredentials;
  @override
  Future<ProposalSessionLease> active({
    bool allowCreate = false,
    String? expectedScope,
  }) async {
    final generation = _generation;
    if (account.authenticating || account.signingOut)
      throw const LocalDataResetException();
    final isAccount = account.hasCredentials;
    final source = isAccount
        ? await account.active()
        : await guest.active(
            allowCreate: allowCreate,
            expectedScope: expectedScope,
          );
    if (_generation != generation) throw const LocalDataResetException();
    if (expectedScope != null && expectedScope != source.submissionScope)
      throw const LocalDataResetException();
    _leases[source.token] = (account: isAccount, lease: source);
    return ProposalSessionLease(
      token: source.token,
      submissionScope: source.submissionScope,
      epoch: source.epoch,
      generation: generation,
    );
  }

  @override
  void checkLease(ProposalSessionLease lease) {
    final source = _leases[lease.token];
    if (_generation != lease.generation ||
        source == null ||
        source.account != account.hasCredentials ||
        account.authenticating ||
        account.signingOut)
      throw const LocalDataResetException();
    if (source.account) {
      account.checkLease(source.lease);
    } else {
      guest.checkLease(source.lease);
    }
  }

  @override
  Future<ProposalSessionLease?> existing() async => account.hasCredentials
      ? active()
      : await guest.existing() == null
      ? null
      : active();
  @override
  Future<void> revokeBeforeReset() async {
    if (account.hasCredentials || account.authenticating)
      await account.logout();
    await guest.revokeBeforeReset();
  }

  @override
  void dispose() {
    account.removeListener(_changed);
    super.dispose();
  }
}
