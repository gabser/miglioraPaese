/// A lease belongs to one persisted server scope and one local generation.
class ProposalSessionLease {
  const ProposalSessionLease({
    required this.token,
    required this.submissionScope,
    required this.epoch,
    required this.generation,
  });
  final String token;
  final String submissionScope;
  final int epoch;
  final int generation;
  Map<String, String> get headers => {'Authorization': 'Bearer $token'};
}

abstract interface class SessionLeaseSource {
  Future<ProposalSessionLease> active({
    bool allowCreate = false,
    String? expectedScope,
  });
  Future<ProposalSessionLease?> existing();
  void checkLease(ProposalSessionLease lease);
  Future<void> revokeBeforeReset();
  bool get preservesCompetitiveDataOnReset;
}
