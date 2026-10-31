import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_draft.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_draft_controller.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_scope_notice.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_similarity_controller.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_similarity_panel.dart';

class SuggestProblemPage extends StatelessWidget {
  const SuggestProblemPage({this.routeContext, super.key});

  final ProposalRouteContext? routeContext;

  @override
  Widget build(BuildContext context) {
    final scope =
        routeContext ??
        ProposalRouteContext.fromPreference(
          context.watch<AppPrefs>().municipalityId,
        );
    if (scope.invalid) {
      return const ProposalScopeNotice(
        invalid: true,
        returnTo: '/suggest-problem',
      );
    }
    return _SuggestProblemView(key: ValueKey(scope.key), routeContext: scope);
  }
}

class _SuggestProblemView extends StatefulWidget {
  const _SuggestProblemView({required this.routeContext, super.key});
  final ProposalRouteContext routeContext;

  @override
  State<_SuggestProblemView> createState() => _SuggestProblemViewState();
}

class _SuggestProblemViewState extends State<_SuggestProblemView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  var _formKey = GlobalKey<FormState>();
  final _titleFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _categoryFocus = FocusNode();
  ProblemKey? _category;
  ProposalLocationKind? _locationKind;
  final _labelController = TextEditingController();
  final _civicController = TextEditingController();
  final _referenceController = TextEditingController();
  final _kindFocus = FocusNode();
  final _labelFocus = FocusNode();
  final _civicFocus = FocusNode();
  final _referenceFocus = FocusNode();
  final _optionalDetails = ExpansibleController();
  bool _reviewing = false;
  Map<String, String> _serverFieldErrors = const {};
  bool _capabilitiesReady = true;
  String? _capabilityError;
  ProposalDraftController? _draftController;
  bool _restoring = false;
  bool _sending = false;
  ProposalSimilarityController? _similarity;

  void _similarityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_recordDraft);
    _descriptionController.addListener(_recordDraft);
    _labelController.addListener(_recordDraft);
    _civicController.addListener(_recordDraft);
    _referenceController.addListener(_recordDraft);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefs = context.watch<AppPrefs>();
    context.watch<ProposalSubmissionCoordinator>();
    final municipality = widget.routeContext.municipalityId;
    final scope = municipality == null || municipality.trim().isEmpty
        ? null
        : ProposalScope.fromConfig(
            municipalityId: municipality,
            config: context.read<AppConfig?>() ?? AppConfig.fromValues(),
            namespace: prefs.localData.namespace,
          );
    if (_draftController?.scope == scope) return;
    _serverFieldErrors = const {};
    _similarity?.removeListener(_similarityChanged);
    _similarity?.dispose();
    _similarity = scope == null
        ? null
        : ProposalSimilarityController(
            repository: context.read<NextProblemsRepository>(),
            scope: scope,
            data: prefs.localData,
          );
    _similarity?.addListener(_similarityChanged);
    _draftController?.removeListener(_draftChanged);
    _draftController?.dispose();
    _draftController = scope == null
        ? null
        : ProposalDraftController(
            store:
                context.read<ProposalDraftStore?>() ??
                ProposalDraftStore(prefs.localData),
            scope: scope,
          );
    _draftController?.addListener(_draftChanged);
    _applyDraft(_draftController?.draft ?? const ProposalDraft());
    _formKey = GlobalKey<FormState>();
    _capabilityError = null;
    _capabilitiesReady =
        context.read<AppConfig?>()?.nextProblemsDataSource !=
        NextProblemsDataSource.api;
    if (!_capabilitiesReady && scope != null) {
      unawaited(_prepareCapabilities(scope));
    }
  }

  Future<void> _prepareCapabilities(ProposalScope scope) async {
    try {
      await context.read<ProposalSubmissionCoordinator>().prepareForm(scope);
      if (!mounted || _draftController?.scope != scope) return;
      setState(() {
        _capabilitiesReady = true;
        _capabilityError = null;
      });
    } catch (_) {
      if (!mounted || _draftController?.scope != scope) return;
      setState(() {
        _capabilitiesReady = false;
        _capabilityError =
            'Non riesco a verificare il servizio proposte. La bozza resta su questo dispositivo.';
      });
    }
  }

  void _applyDraft(ProposalDraft draft) {
    _restoring = true;
    _titleController.text = draft.title;
    _descriptionController.text = draft.description;
    _category = draft.category;
    _locationKind = draft.locationKind;
    _labelController.text = draft.locationLabel;
    _civicController.text = draft.civic;
    _referenceController.text = draft.reference;
    _reviewing = false;
    _similarity?.invalidate();
    _restoring = false;
  }

  void _recordDraft() {
    if (_restoring || _draftController == null) return;
    final prior = _draftController!.draft;
    if (prior.title == _titleController.text &&
        prior.description == _descriptionController.text &&
        prior.category == _category &&
        prior.locationKind == _locationKind &&
        prior.locationLabel == _labelController.text &&
        prior.civic == _civicController.text &&
        prior.reference == _referenceController.text) {
      return;
    }
    _reviewing = false;
    _serverFieldErrors = const {};
    _similarity?.invalidate();
    _draftController?.edit(
      ProposalDraft(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _category,
        locationKind: _locationKind,
        locationLabel: _labelController.text,
        civic: _civicController.text,
        reference: _referenceController.text,
      ),
    );
  }

  void _draftChanged() {
    if (!mounted) return;
    if (_draftController?.status == DraftSaveStatus.reset) {
      _applyDraft(const ProposalDraft());
      _formKey = GlobalKey<FormState>();
    }
    setState(() {});
  }

  Future<void> _leave() async {
    final saved = await _draftController?.flush() ?? true;
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La bozza non è stata salvata. Riprova prima di uscire.',
          ),
        ),
      );
      return;
    }
    context.go(
      ProposalRouteContext.location(
        '/next-problems',
        widget.routeContext.municipalityId,
      ),
    );
  }

  Widget _draftStatus() {
    final status = _draftController?.status;
    final text = switch (status) {
      DraftSaveStatus.empty =>
        'La bozza viene salvata su questo dispositivo mentre scrivi.',
      DraftSaveStatus.restored => 'Bozza recuperata da questo dispositivo.',
      DraftSaveStatus.saving => 'Salvataggio della bozza…',
      DraftSaveStatus.saved => 'Bozza salvata su questo dispositivo.',
      DraftSaveStatus.failed =>
        'Non riesco a salvare la bozza. Mantieni aperta questa pagina e riprova.',
      DraftSaveStatus.reset =>
        'Dati locali azzerati. Scegli di nuovo il Comune.',
      null => 'Scegli il Comune prima di compilare la proposta.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion:
              status == DraftSaveStatus.failed ||
              status == DraftSaveStatus.restored ||
              status == DraftSaveStatus.reset,
          child: Text(text, key: const ValueKey('proposal-draft-status')),
        ),
        if (status == DraftSaveStatus.failed)
          TextButton(
            onPressed: _draftController!.retry,
            child: const Text('Riprova il salvataggio'),
          ),
      ],
    );
  }

  String? _requiredText(String? value, String label, int limit) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return label == 'Descrizione'
          ? 'Descrizione obbligatoria.'
          : '$label obbligatorio.';
    }
    if (text.runes.length > limit) return 'Usa al massimo $limit caratteri.';
    try {
      ProposalLimits.text(text, limit);
    } on FormatException {
      return 'Controlla il testo inserito.';
    }
    return null;
  }

  Widget _counter(TextEditingController controller, int limit) {
    final count = ProposalLimits.length(controller.text);
    return Semantics(
      label: '$count di $limit caratteri',
      excludeSemantics: true,
      child: Text('$count/$limit'),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _similarity?.removeListener(_similarityChanged);
    _similarity?.dispose();
    _titleController.removeListener(_recordDraft);
    _descriptionController.removeListener(_recordDraft);
    _labelController.removeListener(_recordDraft);
    _civicController.removeListener(_recordDraft);
    _referenceController.removeListener(_recordDraft);
    _labelController.dispose();
    _civicController.dispose();
    _referenceController.dispose();
    _kindFocus.dispose();
    _labelFocus.dispose();
    _civicFocus.dispose();
    _referenceFocus.dispose();
    _optionalDetails.dispose();
    _draftController?.removeListener(_draftChanged);
    _draftController?.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _categoryFocus.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !_capabilitiesReady) return;
    final prefs = context.read<AppPrefs>();
    if (widget.routeContext.municipalityId == null) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      if (_requiredText(
            _titleController.text,
            'Titolo',
            ProposalLimits.title,
          ) !=
          null) {
        _titleFocus.requestFocus();
      } else if (_requiredText(
            _descriptionController.text,
            'Descrizione',
            ProposalLimits.description,
          ) !=
          null) {
        _descriptionFocus.requestFocus();
      } else if (_category == null) {
        _categoryFocus.requestFocus();
      } else if (_locationKind == null) {
        _kindFocus.requestFocus();
      } else if (_requiredText(
            _labelController.text,
            'Luogo',
            ProposalLimits.label,
          ) !=
          null) {
        _labelFocus.requestFocus();
      } else {
        _optionalDetails.expand();
        final focus =
            _optionalText(_civicController.text, ProposalLimits.civic) != null
            ? _civicFocus
            : _referenceFocus;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) focus.requestFocus();
        });
      }
      return;
    }
    if (_locationKind == ProposalLocationKind.specific) {
      final civicError = _optionalText(
        _civicController.text,
        ProposalLimits.civic,
      );
      final referenceError = _optionalText(
        _referenceController.text,
        ProposalLimits.reference,
      );
      if (civicError != null || referenceError != null) {
        _optionalDetails.expand();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _formKey.currentState?.validate();
          (civicError != null ? _civicFocus : _referenceFocus).requestFocus();
        });
        return;
      }
    }
    if (!_reviewing) {
      setState(() => _reviewing = true);
      final location = _locationKind == ProposalLocationKind.municipality
          ? const ProposalLocation.municipality()
          : ProposalLocation.specific(
              label: _labelController.text,
              civic: _civicController.text,
              reference: _referenceController.text,
            );
      unawaited(
        _similarity!.review(
          title: _titleController.text,
          category: _category!,
          location: location,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final review = _reviewKey.currentContext;
        if (review != null)
          unawaited(
            Scrollable.ensureVisible(
              review,
              duration: const Duration(milliseconds: 200),
            ),
          );
      });
      return;
    }
    if (_similarity?.canProceed != true) return;
    final draftController = _draftController;
    final scope = draftController?.scope;
    if (scope == null) return;
    final coordinator = context.read<ProposalSubmissionCoordinator>();
    if (coordinator.current(scope).blocksNew) return;
    setState(() => _sending = true);
    try {
      final revision = draftController!.draft.revision;
      final epoch = prefs.localData.epoch;
      final title = _titleController.text;
      final description = _descriptionController.text;
      final category = _category!;
      final location = _locationKind == ProposalLocationKind.municipality
          ? const ProposalLocation.municipality()
          : ProposalLocation.specific(
              label: _labelController.text,
              civic: _civicController.text,
              reference: _referenceController.text,
            );
      if (!await draftController.flush()) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La bozza non è stata salvata. Riprova prima di inviare.',
              ),
            ),
          );
        return;
      }
      if (!mounted || prefs.localData.epoch != epoch) return;
      final result = await coordinator.start(
        scope: scope,
        draftRevision: revision,
        title: title,
        description: description,
        category: category,
        location: location,
      );
      if (mounted &&
          prefs.localData.epoch == epoch &&
          _draftController?.scope == scope) {
        _showSubmissionResult(scope, result);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _serverError(String field) {
    final code = _serverFieldErrors[field];
    if (code == null) return null;
    return switch (code) {
      'too_long' => 'Il servizio richiede un testo più breve per questo campo.',
      'invalid_choice' => 'Scegli uno dei valori disponibili.',
      'invalid_location' => 'Controlla il tipo di luogo e i relativi campi.',
      _ => 'Controlla il testo di questo campo.',
    };
  }

  void _showSubmissionResult(ProposalScope scope, SubmissionView result) {
    if (result.fieldErrors.isNotEmpty) {
      setState(() {
        _serverFieldErrors = result.fieldErrors;
        _reviewing = false;
      });
      _similarity?.invalidate();
      const order = [
        'title',
        'description',
        'category',
        'location',
        'location.label',
        'location.civic',
        'location.reference',
      ];
      final field = order.where(result.fieldErrors.containsKey).firstOrNull;
      if (field == 'location.civic' || field == 'location.reference')
        _optionalDetails.expand();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _draftController?.scope != scope) return;
        _formKey.currentState?.validate();
        final focus = switch (field) {
          'title' => _titleFocus,
          'description' => _descriptionFocus,
          'category' => _categoryFocus,
          'location' => _kindFocus,
          'location.label' => _labelFocus,
          'location.civic' => _civicFocus,
          'location.reference' => _referenceFocus,
          _ => null,
        };
        focus?.requestFocus();
        if (focus?.context != null)
          unawaited(Scrollable.ensureVisible(focus!.context!));
      });
    }
    if (result.status == SubmissionStatus.succeeded) {
      context.go(
        ProposalRouteContext.receiptLocation(
          result.intent!.receipt!.id,
          scope.municipalityId,
        ),
      );
    } else if (result.message != null &&
        result.status != SubmissionStatus.outcomeUnknown &&
        result.status != SubmissionStatus.scopeLost &&
        result.status != SubmissionStatus.receiptUnsaved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message!)));
    }
  }

  Future<void> _submissionAction(ProposalScope scope, String action) async {
    final coordinator = context.read<ProposalSubmissionCoordinator>();
    final epoch = context.read<AppPrefs>().localData.epoch;
    if (action == 'abandon') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Abbandonare la verifica?'),
          content: const Text(
            'La proposta potrebbe essere già stata ricevuta. Abbandonare non la cancella. '
            'Lo storico resterà qui; un nuovo invio potrebbe creare un’altra proposta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continua a verificare'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abbandona verifica'),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !mounted ||
          _draftController?.scope != scope ||
          context.read<AppPrefs>().localData.epoch != epoch)
        return;
    }
    final result = await switch (action) {
      'lookup' => coordinator.reconcile(scope),
      'retry' => coordinator.retry(scope),
      'save' => coordinator.persistReceipt(scope),
      _ => coordinator.abandon(scope),
    };
    if (!mounted ||
        _draftController?.scope != scope ||
        context.read<AppPrefs>().localData.epoch != epoch)
      return;
    _showSubmissionResult(scope, result);
    if (action == 'abandon' &&
        result.status == SubmissionStatus.idle &&
        !_capabilitiesReady) {
      unawaited(_prepareCapabilities(scope));
    }
  }

  Widget _submissionStatus(ProposalScope scope, SubmissionView view) {
    if (view.status == SubmissionStatus.succeeded &&
        view.intent?.receipt != null) {
      final receipt = view.intent!.receipt!;
      return FcPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: const Text('Ultimo invio ricevuto'),
            ),
            Text('ID: ${receipt.id}'),
            Text(
              'Comune dell’invio: ${MunicipalityCatalog.displayNameFromId(scope.municipalityId)}',
            ),
            Text('Proposta: ${receipt.title}'),
            Text('Luogo: ${view.intent!.location.displayLabel}'),
            const Text(
              'Questa è la conferma dell’invio, non un’approvazione o una segnalazione ufficiale.',
            ),
            TextButton(
              onPressed: () => context.push(
                ProposalRouteContext.receiptLocation(
                  receipt.id,
                  scope.municipalityId,
                ),
              ),
              child: const Text('Leggi la ricevuta salvata'),
            ),
            TextButton(
              onPressed: () => context.go(
                ProposalRouteContext.location(
                  '/next-problems',
                  scope.municipalityId,
                ),
              ),
              child: const Text('Vai alle proposte'),
            ),
          ],
        ),
      );
    }
    if (!view.blocksNew && view.status != SubmissionStatus.scopeLost)
      return const SizedBox.shrink();
    return FcPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              view.message ??
                  (view.busy
                      ? 'Invio in corso. Puoi uscire: la verifica resterà su questo dispositivo.'
                      : 'L’esito dell’invio è da verificare.'),
            ),
          ),
          if (view.intent != null) ...[
            const SizedBox(height: AppTokens.s8),
            Text('Invio da verificare: ${view.intent!.title}'),
            Text('Luogo: ${view.intent!.location.displayLabel}'),
          ],
          if (!view.busy)
            Wrap(
              spacing: AppTokens.s8,
              runSpacing: AppTokens.s8,
              children: [
                if (view.status == SubmissionStatus.receiptUnsaved)
                  FilledButton(
                    onPressed: () => _submissionAction(scope, 'save'),
                    child: const Text('Salva la conferma'),
                  )
                else ...[
                  FilledButton(
                    onPressed: () => _submissionAction(scope, 'lookup'),
                    child: const Text('Verifica invio'),
                  ),
                  if (view.status != SubmissionStatus.scopeLost)
                    TextButton(
                      onPressed: () => _submissionAction(scope, 'retry'),
                      child: const Text('Riprova lo stesso invio'),
                    ),
                  TextButton(
                    onPressed: () => _submissionAction(scope, 'abandon'),
                    child: const Text('Abbandona verifica'),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  final _reviewKey = GlobalKey();

  String? _optionalText(String? value, int limit) =>
      (value ?? '').trim().isEmpty
      ? null
      : _requiredText(value, 'Riferimento', limit);

  Widget _locationFields(bool enabled) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Dove succede?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: AppTokens.s8),
      DropdownButtonFormField<ProposalLocationKind>(
        key: const ValueKey('proposal-location-kind'),
        initialValue: _locationKind,
        focusNode: _kindFocus,
        isExpanded: true,
        hint: const Text('Scegli il luogo'),
        decoration: const InputDecoration(
          labelText: 'Tipo di luogo',
          helperText: 'Obbligatorio',
        ),
        validator: (value) =>
            _serverError('location') ??
            (value == null ? 'Scegli il tipo di luogo.' : null),
        items: const [
          DropdownMenuItem(
            value: ProposalLocationKind.specific,
            child: Text('Luogo specifico'),
          ),
          DropdownMenuItem(
            value: ProposalLocationKind.municipality,
            child: Text('Intero Comune'),
          ),
        ],
        onChanged: !enabled
            ? null
            : (value) {
                setState(() {
                  _locationKind = value;
                });
                _recordDraft();
              },
      ),
      if (_locationKind == ProposalLocationKind.specific) ...[
        const SizedBox(height: AppTokens.s12),
        TextFormField(
          key: const ValueKey('proposal-location-label'),
          enabled: enabled,
          controller: _labelController,
          focusNode: _labelFocus,
          validator: (value) =>
              _serverError('location.label') ??
              _requiredText(value, 'Luogo', ProposalLimits.label),
          textInputAction: TextInputAction.next,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => _counter(_labelController, ProposalLimits.label),
          decoration: const InputDecoration(
            labelText: 'Nome del luogo',
            hintText: 'Via Milano, parco, incrocio o tratto di strada',
            helperText:
                'Obbligatorio · massimo 120 caratteri · il civico non è necessario',
            helperMaxLines: 4,
            errorMaxLines: 3,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        FcDisclosure(
          storageId: 'proposal-place-details:${_draftController?.scope.key}',
          controller: _optionalDetails,
          title: 'Riferimenti facoltativi',
          children: [
            TextFormField(
              key: const ValueKey('proposal-location-civic'),
              enabled: enabled,
              controller: _civicController,
              focusNode: _civicFocus,
              validator: (value) =>
                  _serverError('location.civic') ??
                  _optionalText(value, ProposalLimits.civic),
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => _counter(_civicController, ProposalLimits.civic),
              decoration: const InputDecoration(
                labelText: 'Civico',
                hintText: 'Ad esempio 12/A',
                helperText: 'Facoltativo · massimo 20 caratteri',
                helperMaxLines: 3,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppTokens.s12),
            TextFormField(
              key: const ValueKey('proposal-location-reference'),
              enabled: enabled,
              controller: _referenceController,
              focusNode: _referenceFocus,
              minLines: 2,
              maxLines: 4,
              validator: (value) =>
                  _serverError('location.reference') ??
                  _optionalText(value, ProposalLimits.reference),
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      _counter(_referenceController, ProposalLimits.reference),
              decoration: const InputDecoration(
                labelText: 'Come riconoscere il punto',
                hintText: 'Ingresso del parco, incrocio o tratto interessato',
                helperText: 'Facoltativo · massimo 200 caratteri',
                helperMaxLines: 3,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ],
    ],
  );

  void _edit(FocusNode focus, {bool optional = false}) {
    setState(() => _reviewing = false);
    _similarity?.invalidate();
    if (optional) _optionalDetails.expand();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focus.requestFocus();
      final target = focus.context;
      if (target != null)
        unawaited(
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 200),
          ),
        );
    });
  }

  Widget _review(String municipality) {
    final location = _locationKind == ProposalLocationKind.municipality
        ? const ProposalLocation.municipality()
        : ProposalLocation.specific(
            label: _labelController.text,
            civic: _civicController.text,
            reference: _referenceController.text,
          );
    Widget row(String label, String value, FocusNode focus) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Text(value),
        TextButton(
          onPressed: () => _edit(focus),
          child: Text('Modifica ${label.toLowerCase()}'),
        ),
      ],
    );
    return FcPanel(
      key: _reviewKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            liveRegion: true,
            excludeSemantics: true,
            label: 'Riepilogo pronto. Controlla la proposta prima di inviare.',
            child: Text(
              'Riepilogo della proposta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            'Comune: ${MunicipalityCatalog.displayNameFromId(municipality)}',
          ),
          row('Titolo', _titleController.text.trim(), _titleFocus),
          row(
            'Descrizione',
            _descriptionController.text.trim(),
            _descriptionFocus,
          ),
          row(
            'Categoria',
            AppIcons.labelForProblemKey(_category!),
            _categoryFocus,
          ),
          row('Luogo', location.displayLabel, _kindFocus),
          if (location.reference != null)
            Text('Riferimento: ${location.reference}'),
          if (location.kind == ProposalLocationKind.specific)
            TextButton(
              onPressed: () => _edit(_labelFocus),
              child: const Text('Modifica nome del luogo'),
            ),
          if (location.civic != null || location.reference != null)
            TextButton(
              onPressed: () => _edit(_civicFocus, optional: true),
              child: const Text('Modifica riferimenti'),
            ),
        ],
      ),
    );
  }

  Timer? _cooldownTimer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final municipalityId = widget.routeContext.municipalityId;
    final submissionScope = _draftController?.scope;
    final submission = submissionScope == null
        ? const SubmissionView(SubmissionStatus.idle)
        : context.watch<ProposalSubmissionCoordinator>().current(
            submissionScope,
          );
    final cooldown = submissionScope == null
        ? null
        : context.read<ProposalSubmissionCoordinator>().mockCooldownRemaining(
            submissionScope,
          );
    if (cooldown != null && _cooldownTimer == null) {
      _cooldownTimer = Timer(cooldown, () {
        _cooldownTimer = null;
        if (mounted) setState(() {});
      });
    } else if (cooldown == null && _cooldownTimer != null) {
      _cooldownTimer!.cancel();
      _cooldownTimer = null;
    }
    final hasMunicipality =
        municipalityId != null && municipalityId.trim().isNotEmpty;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _leave,
          tooltip: 'Torna ai temi',
          icon: const Icon(AppIcons.back),
        ),
        title: const Text(VenialCopy.appTitle),
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: AppTokens.narrowContentWidth,
          child: Padding(
            padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: FcPanel(
                tint: AppTokens.blue,
                elevated: true,
                child: Builder(
                  builder: (context) {
                    return Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: FcStatusChip(
                              label: VenialCopy.suggestRibbonLabel,
                              color: AppTokens.blue,
                              icon: AppIcons.play,
                            ),
                          ),
                          SizedBox(
                            height: isCompact ? AppTokens.s8 : AppTokens.s12,
                          ),
                          Text(
                            VenialCopy.suggestTitle,
                            style: TypographyX.titleLarge(context),
                          ),
                          const SizedBox(height: AppTokens.s8),
                          _draftStatus(),
                          if (submissionScope != null)
                            _submissionStatus(submissionScope, submission),
                          if (cooldown != null) ...[
                            const SizedBox(height: AppTokens.s8),
                            Text(
                              'Modalità demo: puoi inviare una nuova proposta in questo Comune dopo cinque minuti dall’ultimo invio. La bozza resta modificabile.',
                            ),
                          ],
                          if (!_capabilitiesReady) ...[
                            const SizedBox(height: AppTokens.s8),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _capabilityError ??
                                    'Verifica del servizio proposte…',
                              ),
                            ),
                            if (_capabilityError != null)
                              TextButton(
                                onPressed: () {
                                  final scope = _draftController?.scope;
                                  if (scope != null)
                                    unawaited(_prepareCapabilities(scope));
                                },
                                child: const Text('Riprova la verifica'),
                              ),
                          ],
                          const SizedBox(height: AppTokens.s8),
                          Text(
                            VenialCopy.suggestSubtitle,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppTokens.s8),
                          if (hasMunicipality)
                            Text(
                              'Comune: ${MunicipalityCatalog.displayNameFromId(municipalityId)}',
                            )
                          else ...[
                            const Text(
                              'Scegli un Comune prima di inviare una proposta.',
                            ),
                            TextButton(
                              onPressed: () => context.go(
                                '/onboarding?returnTo=/suggest-problem',
                              ),
                              child: const Text('Scegli il Comune'),
                            ),
                          ],
                          const SizedBox(height: AppTokens.s8),
                          Container(
                            padding: const EdgeInsets.all(AppTokens.s12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSmall,
                              ),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              VenialCopy.suggestOfficialHint,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: isCompact ? AppTokens.s12 : AppTokens.s16,
                          ),
                          TextFormField(
                            key: const ValueKey('proposal-title'),
                            enabled: hasMunicipality,
                            focusNode: _titleFocus,
                            validator: (value) =>
                                _serverError('title') ??
                                _requiredText(
                                  value,
                                  'Titolo',
                                  ProposalLimits.title,
                                ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _descriptionFocus.requestFocus(),
                            controller: _titleController,
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => _counter(
                                  _titleController,
                                  ProposalLimits.title,
                                ),
                            decoration: const InputDecoration(
                              labelText: 'Titolo del problema',
                              helperText:
                                  'Obbligatorio · massimo 120 caratteri',
                              helperMaxLines: 3,
                              errorMaxLines: 3,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              hintText: VenialCopy.suggestTitleHint,
                            ),
                          ),
                          SizedBox(
                            height: isCompact ? AppTokens.s8 : AppTokens.s12,
                          ),
                          TextFormField(
                            key: const ValueKey('proposal-description'),
                            enabled: hasMunicipality,
                            focusNode: _descriptionFocus,
                            validator: (value) =>
                                _serverError('description') ??
                                _requiredText(
                                  value,
                                  'Descrizione',
                                  ProposalLimits.description,
                                ),
                            controller: _descriptionController,
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => _counter(
                                  _descriptionController,
                                  ProposalLimits.description,
                                ),
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Descrizione del problema',
                              helperText:
                                  'Obbligatoria · massimo 1000 caratteri',
                              helperMaxLines: 3,
                              errorMaxLines: 3,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              hintText: VenialCopy.suggestDescriptionHint,
                            ),
                          ),
                          SizedBox(
                            height: isCompact ? AppTokens.s8 : AppTokens.s12,
                          ),
                          DropdownButtonFormField<ProblemKey>(
                            key: const ValueKey('proposal-category'),
                            initialValue: _category,
                            focusNode: _categoryFocus,
                            isExpanded: true,
                            hint: const Text('Scegli una categoria'),
                            validator: (value) =>
                                _serverError('category') ??
                                (value == null
                                    ? 'Scegli una categoria.'
                                    : null),
                            items: ProblemKey.values
                                .map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Text(
                                      AppIcons.labelForProblemKey(key),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: !hasMunicipality
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _category = value;
                                    });
                                    _recordDraft();
                                  },
                            decoration: const InputDecoration(
                              labelText: VenialCopy.suggestCategoryLabel,
                              helperText: 'Obbligatoria',
                            ),
                          ),
                          const SizedBox(height: AppTokens.s16),
                          _locationFields(
                            hasMunicipality && _capabilitiesReady,
                          ),
                          const SizedBox(height: AppTokens.s16),
                          if (_reviewing) _review(municipalityId!),
                          if (_reviewing && _similarity != null) ...[
                            const SizedBox(height: AppTokens.s12),
                            ProposalSimilarityPanel(controller: _similarity!),
                          ],
                          Text(
                            VenialCopy.suggestReviewHint,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(
                            height: isCompact ? AppTokens.s12 : AppTokens.s16,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppTokens.s8,
                              children: [
                                if (submission.busy) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: AppTokens.s8),
                                ],
                                FilledButton(
                                  key: const ValueKey('proposal-submit'),
                                  onPressed:
                                      _sending ||
                                          submission.blocksNew ||
                                          (_reviewing && cooldown != null) ||
                                          !hasMunicipality ||
                                          (_reviewing &&
                                              _similarity?.canProceed !=
                                                  true) ||
                                          !_capabilitiesReady
                                      ? null
                                      : _submit,
                                  child: Text(
                                    _reviewing
                                        ? VenialCopy.suggestSubmit
                                        : 'Controlla la proposta',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
