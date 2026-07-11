import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_cubit.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_state.dart';

class SuggestProblemPage extends StatelessWidget {
  const SuggestProblemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NextProblemsCubit(
        repository: context.read<NextProblemsRepository>(),
        prefs: context.read<AppPrefs>(),
      ),
      child: const _SuggestProblemView(),
    );
  }
}

class _SuggestProblemView extends StatefulWidget {
  const _SuggestProblemView();

  @override
  State<_SuggestProblemView> createState() => _SuggestProblemViewState();
}

class _SuggestProblemViewState extends State<_SuggestProblemView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  ProblemKey _category = ProblemKey.potholes;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prefs = context.read<AppPrefs>();
    if (!prefs.canSuggestNow()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(VenialCopy.suggestCooldownHint)),
      );
      return;
    }
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      setState(() {
        _error = VenialCopy.suggestMissingFields;
      });
      return;
    }
    if (title.length > 60 || description.length > 140) {
      setState(() {
        _error = VenialCopy.suggestTooLong;
      });
      return;
    }
    setState(() {
      _error = null;
    });

    final cubit = context.read<NextProblemsCubit>();
    final error = await cubit.submit(
      title: title,
      description: description,
      category: _category,
    );
    if (!mounted) return;
    if (error == null) {
      await prefs.setLastSuggestedAt(DateTime.now());
      if (!mounted) return;
      context.go('/next-problems');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(VenialCopy.suggestSuccess)));
      return;
    }
    if (error == 'duplicate_title') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(VenialCopy.suggestDuplicateHint)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(VenialCopy.suggestGenericError)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/next-problems'),
          tooltip: 'Torna ai temi',
          icon: const Icon(AppIcons.back),
        ),
        title: const Text(VenialCopy.appTitle),
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          child: Padding(
            padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: FcPanel(
                tint: AppTokens.blue,
                elevated: true,
                child: BlocBuilder<NextProblemsCubit, NextProblemsState>(
                  builder: (context, state) {
                    return Column(
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
                        Text(
                          VenialCopy.suggestSubtitle,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                        TextField(
                          controller: _titleController,
                          maxLength: 60,
                          decoration: const InputDecoration(
                            hintText: VenialCopy.suggestTitleHint,
                          ),
                        ),
                        SizedBox(
                          height: isCompact ? AppTokens.s8 : AppTokens.s12,
                        ),
                        TextField(
                          controller: _descriptionController,
                          maxLength: 140,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: VenialCopy.suggestDescriptionHint,
                          ),
                        ),
                        SizedBox(
                          height: isCompact ? AppTokens.s8 : AppTokens.s12,
                        ),
                        DropdownButtonFormField<ProblemKey>(
                          value: _category,
                          items: ProblemKey.values
                              .map(
                                (key) => DropdownMenuItem(
                                  value: key,
                                  child: Text(AppIcons.labelForProblemKey(key)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _category = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: VenialCopy.suggestCategoryLabel,
                          ),
                        ),
                        const SizedBox(height: AppTokens.s8),
                        Text(
                          VenialCopy.suggestReviewHint,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppTokens.s8),
                          Text(
                            _error!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                        SizedBox(
                          height: isCompact ? AppTokens.s12 : AppTokens.s16,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (state.submitting) ...[
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: AppTokens.s8),
                              ],
                              FilledButton.icon(
                                onPressed: state.submitting ? null : _submit,
                                icon: const Icon(AppIcons.play),
                                label: const Text(VenialCopy.suggestSubmit),
                              ),
                            ],
                          ),
                        ),
                      ],
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
