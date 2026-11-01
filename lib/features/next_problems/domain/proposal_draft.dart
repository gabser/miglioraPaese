import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';

const _unchanged = Object();

/// Raw answers survive validation failures and process restarts, scoped by Comune.
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
    this.step = 0,
    this.caseIndex,
    this.detail,
    this.customDescription = '',
    this.coordinates,
    this.titleCustomized = false,
    this.descriptionCustomized = false,
  });
  final String title,
      description,
      locationLabel,
      civic,
      reference,
      customDescription;
  final ProblemKey? category;
  final ProposalLocationKind? locationKind;
  final int revision, step;

  /// -1 represents the custom case (including migrated v1 drafts).
  final int? caseIndex;
  final String? detail;
  final ProposalCoordinates? coordinates;
  final bool titleCustomized, descriptionCustomized;
  bool get isEmpty =>
      title.isEmpty &&
      description.isEmpty &&
      category == null &&
      locationKind == null &&
      locationLabel.isEmpty &&
      civic.isEmpty &&
      reference.isEmpty &&
      coordinates == null &&
      caseIndex == null &&
      customDescription.isEmpty;

  ProposalDraft copyWith({
    String? title,
    String? description,
    Object? category = _unchanged,
    Object? locationKind = _unchanged,
    String? locationLabel,
    String? civic,
    String? reference,
    int? revision,
    int? step,
    Object? caseIndex = _unchanged,
    Object? detail = _unchanged,
    String? customDescription,
    Object? coordinates = _unchanged,
    bool? titleCustomized,
    bool? descriptionCustomized,
  }) => ProposalDraft(
    title: title ?? this.title,
    description: description ?? this.description,
    category: identical(category, _unchanged)
        ? this.category
        : category as ProblemKey?,
    locationKind: identical(locationKind, _unchanged)
        ? this.locationKind
        : locationKind as ProposalLocationKind?,
    locationLabel: locationLabel ?? this.locationLabel,
    civic: civic ?? this.civic,
    reference: reference ?? this.reference,
    revision: revision ?? this.revision,
    step: step ?? this.step,
    caseIndex: identical(caseIndex, _unchanged)
        ? this.caseIndex
        : caseIndex as int?,
    detail: identical(detail, _unchanged) ? this.detail : detail as String?,
    customDescription: customDescription ?? this.customDescription,
    coordinates: identical(coordinates, _unchanged)
        ? this.coordinates
        : coordinates as ProposalCoordinates?,
    titleCustomized: titleCustomized ?? this.titleCustomized,
    descriptionCustomized: descriptionCustomized ?? this.descriptionCustomized,
  );
  ProposalDraft withRevision(int value) => copyWith(revision: value);
  ProposalLocation get location =>
      locationKind == ProposalLocationKind.municipality
      ? const ProposalLocation.municipality()
      : ProposalLocation.specific(
          label: locationLabel,
          civic: civic,
          reference: reference,
          coordinates: coordinates,
        );

  Map<String, Object?> toJson() => {
    'version': 2,
    'revision': revision,
    'title': title,
    'description': description,
    'category': category?.name,
    'locationKind': locationKind?.name,
    'locationLabel': locationLabel,
    'civic': civic,
    'reference': reference,
    'step': step,
    'caseIndex': caseIndex,
    'detail': detail,
    'customDescription': customDescription,
    'coordinates': coordinates?.toJson(),
    'titleCustomized': titleCustomized,
    'descriptionCustomized': descriptionCustomized,
  };
  static ProposalDraft fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        ![1, 2].contains(raw['version']) ||
        raw['revision'] is! int ||
        (raw['revision'] as int) < 0 ||
        [
          'title',
          'description',
          'locationLabel',
          'civic',
          'reference',
        ].any((key) => raw[key] is! String)) {
      throw const FormatException('Bozza non leggibile.');
    }
    final legacy = raw['version'] == 1;
    if (!legacy &&
        (raw['step'] is! int ||
            (raw['step'] as int) < 0 ||
            (raw['step'] as int) > 2 ||
            raw['caseIndex'] != null &&
                (raw['caseIndex'] is! int ||
                    (raw['caseIndex'] as int) < -1 ||
                    (raw['caseIndex'] as int) > 2) ||
            raw['detail'] != null && raw['detail'] is! String ||
            raw['customDescription'] is! String ||
            raw['titleCustomized'] is! bool ||
            raw['descriptionCustomized'] is! bool)) {
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
      step: legacy ? 0 : raw['step'] as int,
      caseIndex: legacy ? -1 : raw['caseIndex'] as int?,
      detail: legacy ? null : raw['detail'] as String?,
      customDescription: legacy
          ? raw['description'] as String
          : raw['customDescription'] as String,
      coordinates: raw['coordinates'] == null
          ? null
          : ProposalCoordinates.fromJson(raw['coordinates']),
      titleCustomized: legacy ? true : raw['titleCustomized'] as bool,
      descriptionCustomized: legacy
          ? true
          : raw['descriptionCustomized'] as bool,
    );
  }
}
