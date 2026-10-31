import 'dart:convert';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/data/suggested_problem_mapper.dart';

enum SubmissionPhase {
  prepared,
  outcomeUnknown,
  succeeded,
  rejected,
  abandoned,
  scopeLost,
}

/// The normalized payload and technical identity never change after creation.
/// Tokens remain in ProposalSessionStore, rather than in submission history.
class ProposalSubmissionIntent {
  ProposalSubmissionIntent({
    required this.scope,
    required this.idempotencyKey,
    required this.submissionScope,
    required this.draftRevision,
    required this.createdAt,
    required String title,
    required String description,
    required this.category,
    required this.location,
    this.phase = SubmissionPhase.prepared,
    this.receipt,
    this.acceptedAt,
    this.errorCode,
  }) : title = ProposalLimits.text(title, ProposalLimits.title),
       description = ProposalLimits.text(
         description,
         ProposalLimits.description,
       ) {
    if (!RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._:-]{7,159}$',
        ).hasMatch(idempotencyKey) ||
        submissionScope.isEmpty ||
        scope.namespace.isEmpty ||
        scope.environment.isEmpty ||
        ProposalScope.canonicalMunicipality(scope.municipalityId) !=
            scope.municipalityId ||
        draftRevision < 0 ||
        (phase == SubmissionPhase.succeeded) != (receipt != null) ||
        (phase == SubmissionPhase.succeeded) != (acceptedAt != null) ||
        (receipt != null && !matches(receipt!))) {
      throw const FormatException('Intento di invio non valido.');
    }
  }
  final ProposalScope scope;
  final String idempotencyKey, submissionScope, title, description;
  final int draftRevision;
  final DateTime createdAt;
  final ProblemKey category;
  final ProposalLocation location;
  final SubmissionPhase phase;
  final SuggestedProblem? receipt;
  final DateTime? acceptedAt;
  final String? errorCode;

  bool get unresolved =>
      phase == SubmissionPhase.prepared ||
      phase == SubmissionPhase.outcomeUnknown ||
      phase == SubmissionPhase.scopeLost;
  Map<String, Object?> get payload => {
    'title': title,
    'description': description,
    'category': category.name,
    'location': location.toJson(),
  };
  String get fingerprint => jsonEncode([
    scope.key,
    submissionScope,
    idempotencyKey,
    draftRevision,
    createdAt.toUtc().toIso8601String(),
    payload,
  ]);
  bool matches(SuggestedProblem problem) =>
      problem.id.isNotEmpty &&
      problem.title == title &&
      problem.shortDescription == description &&
      problem.category == category &&
      problem.location == location;

  ProposalSubmissionIntent withOutcome(
    SubmissionPhase value, {
    SuggestedProblem? receipt,
    DateTime? acceptedAt,
    String? errorCode,
  }) => ProposalSubmissionIntent(
    scope: scope,
    idempotencyKey: idempotencyKey,
    submissionScope: submissionScope,
    draftRevision: draftRevision,
    createdAt: createdAt,
    title: title,
    description: description,
    category: category,
    location: location,
    phase: value,
    receipt: receipt,
    acceptedAt: acceptedAt,
    errorCode: errorCode,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'scope': {
      'municipalityId': scope.municipalityId,
      'environment': scope.environment,
      'namespace': scope.namespace,
    },
    'idempotencyKey': idempotencyKey,
    'submissionScope': submissionScope,
    'draftRevision': draftRevision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'payload': payload,
    'phase': phase.name,
    'receipt': receipt == null ? null : SuggestedProblemMapper.toJson(receipt!),
    'acceptedAt': acceptedAt?.toUtc().toIso8601String(),
    'errorCode': errorCode,
  };

  static ProposalSubmissionIntent fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw['version'] != 1 ||
        raw.length != 11 ||
        raw['scope'] is! Map<String, dynamic> ||
        raw['payload'] is! Map<String, dynamic>) {
      throw const FormatException('Intento non leggibile.');
    }
    final s = raw['scope'] as Map<String, dynamic>;
    final p = raw['payload'] as Map<String, dynamic>;
    if (s.length != 3 ||
        p.length != 4 ||
        raw['draftRevision'] is! int ||
        raw['errorCode'] != null && raw['errorCode'] is! String) {
      throw const FormatException('Intento non leggibile.');
    }
    return ProposalSubmissionIntent(
      scope: ProposalScope(
        municipalityId: s['municipalityId'] as String,
        environment: s['environment'] as String,
        namespace: s['namespace'] as String,
      ),
      idempotencyKey: raw['idempotencyKey'] as String,
      submissionScope: raw['submissionScope'] as String,
      draftRevision: raw['draftRevision'] as int,
      createdAt: DateTime.parse(raw['createdAt'] as String),
      title: p['title'] as String,
      description: p['description'] as String,
      category: ProblemKey.values.byName(p['category'] as String),
      location:
          ProposalLocation.fromJson(p['location']) ??
          (throw const FormatException('Luogo mancante nell’intento.')),
      phase: SubmissionPhase.values.byName(raw['phase'] as String),
      receipt: raw['receipt'] == null
          ? null
          : SuggestedProblemMapper.fromResponse(raw['receipt']),
      acceptedAt: raw['acceptedAt'] == null
          ? null
          : DateTime.parse(raw['acceptedAt'] as String),
      errorCode: raw['errorCode'] as String?,
    );
  }
}
