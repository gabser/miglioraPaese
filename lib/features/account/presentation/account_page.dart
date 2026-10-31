import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import '../logic/account_controller.dart';
import '../data/account_intent_store.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({this.returnTo, super.key});
  final String? returnTo;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _code = TextEditingController();
  final _pseudonym = TextEditingController();
  final _profileForm = GlobalKey<FormState>();
  bool _intentSaved = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_intentSaved && widget.returnTo != null) {
      _intentSaved = true;
      final controller = context.read<AccountController>();
      if (AccountIntentStore.allows(widget.returnTo!)) {
        controller.intents.remember(widget.returnTo!);
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _pseudonym.dispose();
    super.dispose();
  }

  static bool _syntheticEmail(String value) {
    final address = value.trim().toLowerCase();
    final parts = address.split('@');
    return parts.length == 2 &&
        parts.first.isNotEmpty &&
        (parts.last == 'example.invalid' ||
            parts.last == 'example.com' ||
            parts.last.endsWith('.test'));
  }

  Future<void> _resume(AccountController controller) async {
    final route = await controller.resume();
    if (mounted) context.go(route);
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _submit(AccountController controller) async {
    if (!_form.currentState!.validate()) return;
    if (controller.challenge == null) {
      await controller.sendCode(_email.text);
    } else {
      final accepted = await controller.verify(_code.text);
      if (accepted &&
          controller.conflicts.isEmpty &&
          !controller.linkPending &&
          mounted)
        await _resume(controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountController>();
    final profile = controller.profile;
    final challenge = controller.challenge;
    return Scaffold(
      appBar: AppBar(title: const Text('Account e dispositivi')),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: 720,
          child: SingleChildScrollView(
            key: const ValueKey('account-scroll'),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FcPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accesso locale: consegna simulata',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Questo profilo usa solo indirizzi sintetici: example.invalid, example.com o domini .test. Non invia email reali. Il codice è disponibile esclusivamente nell’adapter privato delle prove locali.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Puoi continuare a esplorare senza account. Squadra e leghe del server possono essere recuperate su un altro dispositivo; la demo locale resta separata.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (controller.busy)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Operazione account in corso',
                  ),
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        controller.error!,
                        key: const ValueKey('account-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (controller.logoutPending)
                  FilledButton(
                    onPressed: controller.busy ? null : controller.logout,
                    child: const Text('Riprova disconnessione'),
                  )
                else if (profile == null)
                  FcPanel(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            challenge == null
                                ? 'Accedi o crea un account'
                                : 'Verifica il codice',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (challenge == null)
                            TextFormField(
                              key: const ValueKey('account-email'),
                              controller: _email,
                              enabled: !controller.busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email sintetica',
                                helperText:
                                    'Esempio: sentinella@example.invalid',
                              ),
                              validator: (value) => _syntheticEmail(value ?? '')
                                  ? null
                                  : 'Usa un indirizzo sintetico dei domini indicati.',
                              onFieldSubmitted: (_) => _submit(controller),
                            )
                          else ...[
                            Text(
                              'Richiesta per ${controller.email}. Scadenza del codice: ${challenge.expiresAt.toLocal().hour.toString().padLeft(2, '0')}:${challenge.expiresAt.toLocal().minute.toString().padLeft(2, '0')}.',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('account-code'),
                              controller: _code,
                              enabled: !controller.busy,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              obscureText: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Codice monouso di sei cifre',
                                errorText:
                                    controller.lastErrorCode?.startsWith(
                                          'code_',
                                        ) ==
                                        true
                                    ? controller.error
                                    : null,
                              ),
                              validator: (value) =>
                                  RegExp(r'^\d{6}$').hasMatch(value ?? '')
                                  ? null
                                  : 'Inserisci sei cifre.',
                              onFieldSubmitted: (_) => _submit(controller),
                            ),
                            TextButton(
                              onPressed:
                                  controller.busy ||
                                      controller.resendRemaining > 0
                                  ? null
                                  : () async {
                                      _code.clear();
                                      await controller.sendCode(
                                        controller.email,
                                      );
                                    },
                              child: Text(
                                controller.resendRemaining > 0
                                    ? 'Richiedi un nuovo codice tra ${controller.resendRemaining}s'
                                    : 'Richiedi un nuovo codice',
                              ),
                            ),
                            TextButton(
                              onPressed: controller.busy
                                  ? null
                                  : () {
                                      _code.clear();
                                      controller.resetChallenge();
                                    },
                              child: const Text('Cambia email'),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: controller.busy
                                ? null
                                : () => _submit(controller),
                            child: Text(
                              challenge == null
                                  ? 'Richiedi codice locale'
                                  : 'Verifica e accedi',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Lo stato ospite del server sarà collegato senza duplicare punti. Se esiste già una squadra dell’account, conserveremo entrambe fino alla tua scelta.',
                          ),
                          TextButton(
                            onPressed: controller.busy
                                ? null
                                : () => _resume(controller),
                            child: const Text(
                              'Continua a esplorare senza account',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  FcPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          profile.pseudonym,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(profile.email),
                        const Text('Email verificata'),
                        const SizedBox(height: 12),
                        Form(
                          key: _profileForm,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                key: const ValueKey('account-pseudonym'),
                                controller: _pseudonym,
                                enabled: !controller.busy,
                                maxLength: 32,
                                decoration: const InputDecoration(
                                  labelText: 'Pseudonimo pubblico',
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().length >= 2
                                    ? null
                                    : 'Usa almeno due caratteri.',
                              ),
                              OutlinedButton(
                                onPressed: controller.busy
                                    ? null
                                    : () async {
                                        if (_profileForm.currentState!
                                            .validate()) {
                                          await controller.updatePseudonym(
                                            _pseudonym.text,
                                          );
                                        }
                                      },
                                child: const Text('Salva pseudonimo'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: controller.busy
                              ? null
                              : () async {
                                  if (await _confirm(
                                    'Disconnettere questo dispositivo?',
                                    'La squadra e le leghe dell’account restano sul server. Le bozze e le ricevute locali vengono conservate.',
                                  ))
                                    await controller.logout();
                                },
                          child: const Text('Disconnetti questo dispositivo'),
                        ),
                      ],
                    ),
                  ),
                  if (controller.conflicts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    FcPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Due squadre separate',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text(
                            'L’account ha già una squadra. Nessuno stato o punteggio è stato sostituito o unito.',
                          ),
                          for (final conflict in controller.conflicts)
                            Text(
                              'Comune: ${MunicipalityCatalog.displayNameFromId(conflict.municipalityId)} · stessa stagione',
                            ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: controller.busy
                                ? null
                                : () async {
                                    if (await _confirm(
                                      'Conservare la squadra dell’account?',
                                      'Abbandonerai esplicitamente la squadra ospite nelle stagioni indicate. La squadra e i punti dell’account restano invariati; nessun punteggio verrà sommato.',
                                    )) {
                                      final accepted = await controller
                                          .linkGuest(keepAccount: true);
                                      if (accepted && mounted)
                                        await _resume(controller);
                                    }
                                  },
                            child: const Text(
                              'Conserva account e abbandona ospite',
                            ),
                          ),
                          TextButton(
                            onPressed: controller.busy
                                ? null
                                : () async {
                                    controller.deferLink();
                                    await _resume(controller);
                                  },
                            child: const Text('Rimanda: conserva entrambe'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (controller.linkPending)
                    OutlinedButton(
                      onPressed: controller.busy ? null : controller.retryLink,
                      child: const Text('Riprova collegamento ospite'),
                    ),
                  if (!controller.linkPending && controller.conflicts.isEmpty)
                    TextButton(
                      onPressed: controller.busy ? null : controller.linkGuest,
                      child: const Text('Verifica collegamento ospite'),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Dispositivi collegati',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: controller.busy ? null : controller.refresh,
                    child: const Text('Aggiorna dispositivi'),
                  ),
                  for (final device in controller.devices.where(
                    (d) => d.revokedAt == null,
                  ))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              device.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              device.isCurrent
                                  ? 'Questo dispositivo'
                                  : 'Altro dispositivo',
                            ),
                            OutlinedButton(
                              onPressed: controller.busy
                                  ? null
                                  : () async {
                                      if (await _confirm(
                                        'Revocare l’accesso?',
                                        'Questo dispositivo perderà l’accesso all’account. La squadra e le leghe restano disponibili dagli altri dispositivi autorizzati.',
                                      ))
                                        await controller.revoke(device);
                                    },
                              child: const Text('Revoca dispositivo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => _resume(controller),
                    child: const Text('Continua a esplorare'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
