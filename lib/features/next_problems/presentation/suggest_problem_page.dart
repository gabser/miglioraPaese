import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_case_catalog.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_point_map.dart';
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
  const SuggestProblemPage({this.routeContext, this.tileProvider, super.key});
  final TileProvider? tileProvider;

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
    return _SuggestProblemView(
      key: ValueKey(scope.key),
      routeContext: scope,
      tileProvider: tileProvider,
    );
  }
}

class _SuggestProblemView extends StatefulWidget {
  const _SuggestProblemView({
    required this.routeContext,
    this.tileProvider,
    super.key,
  });
  final ProposalRouteContext routeContext;
  final TileProvider? tileProvider;

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
  ProposalDraft get _draft => _draftController?.draft ?? const ProposalDraft();
  ProblemKey? get _category => _draft.category;
  ProposalLocationKind? get _locationKind => _draft.locationKind;
  final _customController = TextEditingController();
  final _customFocus = FocusNode();
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
            'Il servizio proposte non è raggiungibile. La bozza resta su questo dispositivo.';
      });
    }
  }

  void _applyDraft(ProposalDraft draft) {
    _restoring = true;
    void sync(TextEditingController controller, String text) {
      if (controller.text != text) controller.text = text;
    }

    sync(_titleController, draft.title);
    sync(_descriptionController, draft.description);
    sync(_labelController, draft.locationLabel);
    sync(_civicController, draft.civic);
    sync(_referenceController, draft.reference);
    sync(_customController, draft.customDescription);
    _restoring = false;
  }

  void _recordDraft() {
    if (_restoring || _draftController == null) return;
    final prior = _draft;
    if (prior.title == _titleController.text &&
        prior.description == _descriptionController.text &&
        prior.locationLabel == _labelController.text &&
        prior.civic == _civicController.text &&
        prior.reference == _referenceController.text) {
      return;
    }
    _reviewing = false;
    _serverFieldErrors = const {};
    _similarity?.invalidate();
    _draftController!.edit(
      prior.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        titleCustomized:
            prior.titleCustomized || prior.title != _titleController.text,
        descriptionCustomized:
            prior.descriptionCustomized ||
            prior.description != _descriptionController.text,
        locationLabel: _labelController.text,
        civic: _civicController.text,
        reference: _referenceController.text,
      ),
    );
  }

  void _answer(VoidCallback action) {
    _reviewing = false;
    _serverFieldErrors = const {};
    _similarity?.invalidate();
    action();
  }

  Future<void> _compare() async {
    if (_category == null) return;
    setState(() => _reviewing = true);
    await _similarity?.review(
      title: _draft.title,
      category: _category!,
      location: _draft.location,
    );
  }

  void _step(int step) {
    _draftController?.goToStep(step);
    _formKey = GlobalKey<FormState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _stepKey.currentContext != null) {
        unawaited(Scrollable.ensureVisible(_stepKey.currentContext!));
        _stepFocus.requestFocus();
      }
    });
  }

  Future<void> _next() async {
    final optionalInvalid =
        _draft.step == 1 &&
        _locationKind == ProposalLocationKind.specific &&
        (_optionalText(_civicController.text, ProposalLimits.civic) != null ||
            _optionalText(
                  _referenceController.text,
                  ProposalLimits.reference,
                ) !=
                null);
    if (optionalInvalid) _optionalDetails.expand();
    if (_formKey.currentState?.validate() != true || optionalInvalid) {
      FocusNode focus;
      if (_draft.step == 0) {
        focus = _draft.caseIndex == -1 ? _customFocus : _categoryFocus;
      } else {
        focus = optionalInvalid
            ? (_optionalText(_civicController.text, ProposalLimits.civic) !=
                      null
                  ? _civicFocus
                  : _referenceFocus)
            : _labelFocus;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _formKey.currentState?.validate();
        focus.requestFocus();
        if (focus.context != null) {
          unawaited(Scrollable.ensureVisible(focus.context!));
        }
      });
      return;
    }
    if (_draft.step == 0) {
      _step(1);
      return;
    }
    _restoring = true;
    _draftController?.regenerate();
    _restoring = false;
    _applyDraft(_draft);
    _step(2);
    await _compare();
  }

  void _draftChanged() {
    if (!mounted) return;
    if (_draftController?.status == DraftSaveStatus.reset) {
      _applyDraft(const ProposalDraft());
      _formKey = GlobalKey<FormState>();
    }
    _applyDraft(_draft);
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
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        ProposalRouteContext.location(
          '/next-problems',
          widget.routeContext.municipalityId,
        ),
      );
    }
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
        'Bozza non salvata. Tieni aperta questa pagina e riprova.',
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
            child: const Text(VenialCopy.retrySaveCta),
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
    _customController.dispose();
    _customFocus.dispose();
    _stepFocus.dispose();
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
    if (_formKey.currentState?.validate() != true) {
      (_requiredText(_titleController.text, 'Titolo', ProposalLimits.title) !=
                  null
              ? _titleFocus
              : _descriptionFocus)
          .requestFocus();
      return;
    }
    if (!_reviewing) {
      await _compare();
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
      final location = _draft.location;
      if (!await draftController.flush()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La bozza non è stata salvata. Riprova prima di inviare.',
              ),
            ),
          );
        }
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
        final placeError = result.fieldErrors.keys.any(
          (field) => field.startsWith('location'),
        );
        _draftController?.goToStep(
          placeError
              ? 1
              : result.fieldErrors.containsKey('category')
              ? 0
              : 2,
        );
        _formKey = GlobalKey<FormState>();
      });
      _similarity?.invalidate();
      const order = [
        'title',
        'description',
        'category',
        'location',
        'location.coordinates',
        'location.label',
        'location.civic',
        'location.reference',
      ];
      final field = order.where(result.fieldErrors.containsKey).firstOrNull;
      if (field == 'location.civic' || field == 'location.reference') {
        _optionalDetails.expand();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _draftController?.scope != scope) return;
        _formKey.currentState?.validate();
        final focus = switch (field) {
          'title' => _titleFocus,
          'description' => _descriptionFocus,
          'category' => _categoryFocus,
          'location' => _kindFocus,
          'location.coordinates' => _kindFocus,
          'location.label' => _labelFocus,
          'location.civic' => _civicFocus,
          'location.reference' => _referenceFocus,
          _ => null,
        };
        focus?.requestFocus();
        if (focus?.context != null) {
          unawaited(Scrollable.ensureVisible(focus!.context!));
        }
      });
    }
    if (result.status == SubmissionStatus.succeeded) {
      final receiptRoute = ProposalRouteContext.receiptLocation(
        result.intent!.receipt!.id,
        scope.municipalityId,
      );
      if (context.canPop()) {
        context.pushReplacement(receiptRoute);
      } else {
        context.go(receiptRoute);
      }
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
          context.read<AppPrefs>().localData.epoch != epoch) {
        return;
      }
    }
    final result = await switch (action) {
      'lookup' => coordinator.reconcile(scope),
      'retry' => coordinator.retry(scope),
      'save' => coordinator.persistReceipt(scope),
      _ => coordinator.abandon(scope),
    };
    if (!mounted ||
        _draftController?.scope != scope ||
        context.read<AppPrefs>().localData.epoch != epoch) {
      return;
    }
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
              'La proposta è stata ricevuta. Non è una segnalazione ufficiale e non entra automaticamente nel gioco.',
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
              onPressed: _leave,
              child: Text(
                (GoRouter.maybeOf(context)?.canPop() ?? false)
                    ? 'Torna indietro'
                    : 'Vai alle proposte',
              ),
            ),
          ],
        ),
      );
    }
    if (!view.blocksNew && view.status != SubmissionStatus.scopeLost) {
      return const SizedBox.shrink();
    }
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
                    child: const Text('Salva la ricevuta'),
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
                _answer(() => _draftController?.chooseKind(value));
              },
      ),
      if (_locationKind == ProposalLocationKind.specific) ...[
        const SizedBox(height: AppTokens.s12),
        if (ProposalMapViews.forMunicipality(
              widget.routeContext.municipalityId!,
            ) !=
            null)
          ProposalPointMap(
            municipalityId: widget.routeContext.municipalityId!,
            coordinates: _draft.coordinates,
            tileProvider: widget.tileProvider,
            onConfirmed: enabled
                ? (point) => _answer(() => _draftController?.choosePin(point))
                : null,
          )
        else
          const Text(
            'In questo Comune puoi indicare il luogo nel campo di testo.',
          ),
        if (_serverError('location.coordinates') != null)
          Text(
            _serverError('location.coordinates')!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_draft.coordinates != null)
          TextButton(
            onPressed: enabled
                ? () => _answer(() => _draftController?.choosePin(null))
                : null,
            child: const Text('Rimuovi pin'),
          ),
        const SizedBox(height: AppTokens.s12),
        TextFormField(
          key: const ValueKey('proposal-location-label'),
          enabled: enabled,
          controller: _labelController,
          focusNode: _labelFocus,
          validator: (value) =>
              _serverError('location.label') ??
              (_draft.coordinates == null
                  ? _requiredText(value, 'Luogo', ProposalLimits.label)
                  : _optionalText(value, ProposalLimits.label)),
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
                'Facoltativo con pin · senza pin indica il nome · massimo 120 caratteri',
            helperMaxLines: 4,
            errorMaxLines: 3,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        FcDisclosure(
          storageId: 'proposal-place-details:${_draftController?.scope.key}',
          controller: _optionalDetails,
          title: 'Aggiungi dettagli del luogo',
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

  final _stepKey = GlobalKey();
  final _stepFocus = FocusNode();

  Widget _problemFields(bool enabled) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FormField<ProblemKey>(
        key: ValueKey('proposal-category-${_category?.name}'),
        initialValue: _category,
        validator: (value) =>
            _serverError('category') ??
            (value == null ? 'Scegli una categoria.' : null),
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quale problema hai notato?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.s8),
            Wrap(
              spacing: AppTokens.s8,
              runSpacing: AppTokens.s8,
              children: [
                for (final category in ProblemKey.values)
                  ChoiceChip(
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.standard,
                    focusNode: category == ProblemKey.values.first
                        ? _categoryFocus
                        : null,
                    key: ValueKey('proposal-category-${category.name}-choice'),
                    avatar: ExcludeSemantics(
                      child: Icon(AppIcons.forProblemKey(category), size: 20),
                    ),
                    label: Text(AppIcons.labelForProblemKey(category)),
                    selected: _category == category,
                    onSelected: enabled
                        ? (_) => _answer(
                            () => _draftController?.chooseCategory(category),
                          )
                        : null,
                  ),
              ],
            ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      if (_category != null) ...[
        const SizedBox(height: AppTokens.s16),
        FormField<int>(
          key: ValueKey('proposal-case-${_category!.name}-${_draft.caseIndex}'),
          initialValue: _draft.caseIndex,
          validator: (value) => value == null ? 'Scegli il tuo caso.' : null,
          builder: (state) => Material(
            type: MaterialType.transparency,
            child: RadioGroup<int>(
              groupValue: _draft.caseIndex,
              onChanged: (value) {
                if (enabled && value != null) {
                  _answer(() => _draftController?.chooseCase(value));
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scegli il tuo caso'),
                  for (final entry
                      in ProposalCaseCatalog.cases[_category]!.indexed)
                    RadioListTile<int>(
                      title: Text(entry.$2),
                      value: entry.$1,
                      enabled: enabled,
                    ),
                  RadioListTile<int>(
                    title: const Text('Il mio caso è diverso'),
                    value: -1,
                    enabled: enabled,
                  ),
                  if (state.hasError)
                    Text(
                      state.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_draft.caseIndex == -1)
          TextFormField(
            key: const ValueKey('proposal-custom-description'),
            controller: _customController,
            focusNode: _customFocus,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Descrivi brevemente il tuo caso',
              helperText: 'Obbligatorio · massimo 1000 caratteri',
              errorMaxLines: 3,
            ),
            minLines: 2,
            maxLines: 4,
            validator: (value) =>
                _requiredText(value, 'Descrizione', ProposalLimits.description),
            onChanged: (value) => _answer(
              () => _draftController?.edit(
                _draft.copyWith(customDescription: value),
              ),
            ),
          ),
        if (ProposalCaseCatalog.details(_draft).isNotEmpty) ...[
          const SizedBox(height: AppTokens.s12),
          Text(ProposalCaseCatalog.detailLabel(_draft)),
          Wrap(
            spacing: AppTokens.s8,
            children: [
              for (final detail in ProposalCaseCatalog.details(_draft))
                ChoiceChip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  label: Text(detail),
                  selected: _draft.detail == detail,
                  onSelected: enabled
                      ? (selected) => _answer(
                          () => _draftController?.chooseDetail(
                            selected ? detail : null,
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ],
    ],
  );

  Widget _textField({
    required String key,
    required String label,
    required TextEditingController controller,
    required FocusNode focus,
    required int limit,
    bool multiline = false,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    focusNode: focus,
    validator: (value) =>
        _serverError(key == 'proposal-title' ? 'title' : 'description') ??
        _requiredText(value, multiline ? 'Descrizione' : 'Titolo', limit),
    minLines: multiline ? 2 : 1,
    maxLines: multiline ? 5 : 2,
    decoration: InputDecoration(
      labelText: label,
      helperText: 'Modificabile · massimo $limit caratteri',
      errorMaxLines: 3,
    ),
    buildCounter:
        (context, {required currentLength, required isFocused, maxLength}) =>
            _counter(controller, limit),
  );

  Widget _review(String municipality) => Column(
    key: _reviewKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Riepilogo della proposta',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppTokens.s12),
      _textField(
        key: 'proposal-title',
        label: 'Titolo del problema',
        controller: _titleController,
        focus: _titleFocus,
        limit: ProposalLimits.title,
      ),
      const SizedBox(height: AppTokens.s12),
      _textField(
        key: 'proposal-description',
        label: 'Descrizione del problema',
        controller: _descriptionController,
        focus: _descriptionFocus,
        limit: ProposalLimits.description,
        multiline: true,
      ),
      TextButton(
        onPressed: () =>
            _answer(() => _draftController?.regenerate(force: true)),
        child: const Text('Rigenera testo dalle scelte'),
      ),
      Text('Categoria: ${AppIcons.labelForProblemKey(_category!)}'),
      Text('Luogo: ${_draft.location.displayLabel}'),
      if (_draft.location.reference != null)
        Text('Riferimento: ${_draft.location.reference}'),
      if (_draft.coordinates != null)
        ProposalPointMap(
          municipalityId: municipality,
          coordinates: _draft.coordinates,
          tileProvider: widget.tileProvider,
        ),
      TextButton(
        onPressed: () => _step(0),
        child: const Text('Modifica problema'),
      ),
      TextButton(
        onPressed: () => _step(1),
        child: const Text('Modifica luogo'),
      ),
      if (_reviewing && _similarity != null)
        ProposalSimilarityPanel(controller: _similarity!),
      const SizedBox(height: AppTokens.s12),
      const Text(VenialCopy.suggestReviewHint),
    ],
  );

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
          tooltip: 'Torna alle proposte',
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
                            const Text(
                              'Nella demo puoi inviare una proposta per Comune ogni 5 minuti. Nel frattempo puoi modificare la bozza.',
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
                                  if (scope != null) {
                                    unawaited(_prepareCapabilities(scope));
                                  }
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
                          Focus(
                            focusNode: _stepFocus,
                            child: Semantics(
                              key: _stepKey,
                              header: true,
                              liveRegion: true,
                              child: Text(
                                'Passaggio ${_draft.step + 1} di 3 · ${['Problema', 'Luogo', 'Riepilogo'][_draft.step]}',
                                style: textTheme.titleMedium,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTokens.s8),
                          LinearProgressIndicator(
                            value: (_draft.step + 1) / 3,
                            semanticsLabel: 'Avanzamento proposta',
                          ),
                          const SizedBox(height: AppTokens.s16),
                          if (_draft.step == 0) _problemFields(hasMunicipality),
                          if (_draft.step == 1)
                            _locationFields(
                              hasMunicipality && _capabilitiesReady,
                            ),
                          if (_draft.step == 2 &&
                              _category != null &&
                              _locationKind != null)
                            _review(municipalityId!),
                          const SizedBox(height: AppTokens.s16),
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
                                if (_draft.step > 0)
                                  TextButton(
                                    onPressed: _sending || submission.busy
                                        ? null
                                        : () => _step(_draft.step - 1),
                                    child: const Text('Indietro'),
                                  ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  key: const ValueKey('proposal-submit'),
                                  onPressed:
                                      _sending ||
                                          submission.blocksNew ||
                                          (_draft.step == 2 &&
                                              cooldown != null) ||
                                          !hasMunicipality ||
                                          (_draft.step == 2 &&
                                              _reviewing &&
                                              _similarity?.canProceed !=
                                                  true) ||
                                          !_capabilitiesReady
                                      ? null
                                      : _draft.step < 2
                                      ? _next
                                      : _submit,
                                  child: Text(
                                    _draft.step < 2
                                        ? 'Continua'
                                        : _reviewing
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
