import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';

/// Raw text is retained even when incomplete or beyond submission limits.
class ProposalDraft {
  const ProposalDraft({
    this.title = '',
    this.description = '',
    this.category,
    this.locationKind,
    this.locationLabel = '',
    this.civic = '',
    this.reference = '',
    this.revision = 0,
  });
  final String title;
  final String description;
  final ProblemKey? category;
  final ProposalLocationKind? locationKind;
  final String locationLabel;
  final String civic;
  final String reference;
  final int revision;
  bool get isEmpty =>
      title.isEmpty &&
      description.isEmpty &&
      category == null &&
      locationKind == null &&
      locationLabel.isEmpty &&
      civic.isEmpty &&
      reference.isEmpty;

  ProposalDraft withRevision(int value) => ProposalDraft(
    title: title,
    description: description,
    category: category,
    locationKind: locationKind,
    locationLabel: locationLabel,
    civic: civic,
    reference: reference,
    revision: value,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'revision': revision,
    'title': title,
    'description': description,
    'category': category?.name,
    'locationKind': locationKind?.name,
    'locationLabel': locationLabel,
    'civic': civic,
    'reference': reference,
  };

  static ProposalDraft fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw['version'] != 1 ||
        raw['revision'] is! int ||
        (raw['revision'] as int) < 0 ||
        raw.length != 9 ||
        [
          'title',
          'description',
          'locationLabel',
          'civic',
          'reference',
        ].any((key) => raw[key] is! String)) {
      throw const FormatException('Bozza non leggibile.');
    }
    return ProposalDraft(
      title: raw['title'] as String,
      description: raw['description'] as String,
      category: raw['category'] == null
          ? null
          : ProblemKey.values.byName(raw['category'] as String),
      locationKind: raw['locationKind'] == null
          ? null
          : ProposalLocationKind.values.byName(raw['locationKind'] as String),
      locationLabel: raw['locationLabel'] as String,
      civic: raw['civic'] as String,
      reference: raw['reference'] as String,
      revision: raw['revision'] as int,
    );
  }
}
