import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../repositories/household_repository.dart';
import '../viewmodels/household_actions.dart';
import '../viewmodels/session_view_model.dart';
import 'membership_views.dart' show actionError;

const _outline = Color(0xFF747686);

class HouseholdSelectionView extends StatelessWidget {
  const HouseholdSelectionView({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => HouseholdActions(context.read<HouseholdRepository>()),
    child: const _SelectionContent(),
  );
}

class _SelectionContent extends StatefulWidget {
  const _SelectionContent();
  @override
  State<_SelectionContent> createState() => _SelectionContentState();
}

class _SelectionContentState extends State<_SelectionContent> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> paste(HouseholdActions vm) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    code.text = text.toUpperCase();
    vm.clearPreview();
    setState(() {});
  }

  Future<void> submitJoin(HouseholdActions vm, SessionViewModel session) async {
    final entered = code.text.trim();
    if (entered.isEmpty) return;
    if (vm.preview == null) {
      await vm.previewCode(entered);
      return;
    }
    String? id;
    final ok = await vm.run(() async {
      id = (await vm.repository.redeem(entered)).id;
    });
    if (ok && mounted) await session.selectHousehold(id!);
  }

  void showFaq(AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.faqTitle,
                style: AppText.headlineSm.copyWith(color: AppColors.text),
              ),
              for (final qa in [
                (l.faqJoinQ, l.faqJoinA),
                (l.faqCodeQ, l.faqCodeA),
                (l.faqMultiQ, l.faqMultiA),
              ]) ...[
                const SizedBox(height: 16),
                Text(
                  qa.$1,
                  style: AppText.labelLg.copyWith(color: AppColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  qa.$2,
                  style: AppText.bodyMd.copyWith(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final session = context.watch<SessionViewModel>();
    final vm = context.watch<HouseholdActions>();
    final preview = vm.preview;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: session.switching
            ? const AppLoadingIndicator()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      8,
                      16,
                      32,
                    ),
                    children: [
                      _SetupHeader(l: l),
                      if (session.errorCode != null) ...[
                        const SizedBox(height: 24),
                        AppErrorState(
                          message: l.householdError,
                          onRetry: session.refresh,
                        ),
                      ],
                      if (session.households.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        for (final household in session.households)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: 12,
                            ),
                            child: _HouseholdRow(
                              household: household,
                              selected:
                                  session.activeHousehold?.id == household.id,
                              onTap: () async {
                                await session.selectHousehold(household.id);
                                if (context.mounted &&
                                    session.activeHousehold != null) {
                                  context.goNamed('home');
                                }
                              },
                            ),
                          ),
                      ],
                      const SizedBox(height: 24),
                      _CreateCard(l: l),
                      const SizedBox(height: 20),
                      _JoinCard(
                        l: l,
                        code: code,
                        vm: vm,
                        onChanged: () {
                          vm.clearPreview();
                          setState(() {});
                        },
                        onPaste: () => paste(vm),
                        onSubmit: () => submitJoin(vm, session),
                        errorText: vm.error == null
                            ? null
                            : actionError(l, vm.error),
                        previewName: preview?.name,
                        previewMembers: preview?.memberCount,
                        alreadyMember: preview?.alreadyMember ?? false,
                      ),
                      const SizedBox(height: 24),
                      _HelpCard(l: l, onFaq: () => showFaq(l)),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: session.logout,
                          child: Text(
                            l.logout,
                            style: AppText.labelLg.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.l});
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: AppPill(
              l.setupBadge.toUpperCase(),
              icon: Icons.family_restroom,
              bg: AppColors.surfaceHigh,
              fg: AppColors.primary,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              style: AppText.labelSm.copyWith(letterSpacing: 0.55),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l.householdConnectionStep,
                  style: AppText.labelSm.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        l.setupTitle,
        style: AppText.headlineLg.copyWith(
          color: AppColors.text,
          letterSpacing: -0.65,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        l.setupSubtitle,
        style: AppText.bodyMd.copyWith(color: AppColors.muted, height: 1.625),
      ),
      const SizedBox(height: 12),
      AppCard(
        color: AppColors.surfaceLow,
        radius: 12,
        padding: const EdgeInsetsDirectional.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(top: 2),
              child: IconTile(
                icon: Icons.lightbulb,
                bg: AppColors.surfaceHighest,
                fg: AppColors.primary,
                size: 32,
                radius: 8,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.familyTip,
                    style: AppText.labelMd.copyWith(color: AppColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.familyTipBody,
                    style: AppText.bodySm.copyWith(
                      color: AppColors.muted,
                      height: 1.375,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HouseholdRow extends StatelessWidget {
  const _HouseholdRow({
    required this.household,
    required this.selected,
    required this.onTap,
  });
  final dynamic household;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.sm,
            border: selected
                ? Border.all(color: AppColors.primaryContainer, width: 2)
                : null,
          ),
          child: Row(
            children: [
              IconTile(
                icon: HouseholdAvatars.icon(household.avatarKey as String?),
                bg: AppColors.surfaceHigh,
                fg: AppColors.primaryContainer,
                size: 44,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      household.name as String,
                      style: AppText.titleMd.copyWith(color: AppColors.text),
                    ),
                    Text(
                      l.memberSummary(
                        household.memberCount as int,
                        household.role == 'admin' ? l.adminRole : l.memberRole,
                      ),
                      style: AppText.bodySm.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({required this.l});
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const IconTile(
              icon: Icons.roofing,
              bg: AppColors.surfaceHigh,
              fg: AppColors.primaryContainer,
              size: 56,
              iconSize: 32,
              radius: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AppPill(
                l.recommendedHeads,
                bg: AppColors.surfaceLow,
                fg: AppColors.primary,
                style: AppText.labelSm.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l.createCardTitle,
          style: AppText.headlineSm.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: 6),
        Text(
          l.createCardBody,
          style: AppText.bodyMd.copyWith(color: AppColors.muted, height: 1.625),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FeatureChip(
              Icons.admin_panel_settings_outlined,
              AppColors.primary,
              l.adminControls,
            ),
            _FeatureChip(
              Icons.share_outlined,
              AppColors.secondary,
              l.inviteLinkCode,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCta(
          label: l.createHousehold,
          trailingIcon: Icons.arrow_forward,
          onPressed: () => context.goNamed('createHousehold'),
        ),
      ],
    ),
  );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.icon, this.iconColor, this.label);
  final IconData icon;
  final Color iconColor;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Text(label, style: AppText.labelSm.copyWith(color: AppColors.muted)),
      ],
    ),
  );
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.l,
    required this.code,
    required this.vm,
    required this.onChanged,
    required this.onPaste,
    required this.onSubmit,
    required this.errorText,
    required this.previewName,
    required this.previewMembers,
    required this.alreadyMember,
  });
  final AppLocalizations l;
  final TextEditingController code;
  final HouseholdActions vm;
  final VoidCallback onChanged;
  final VoidCallback onPaste;
  final VoidCallback onSubmit;
  final String? errorText;
  final String? previewName;
  final int? previewMembers;
  final bool alreadyMember;
  @override
  Widget build(BuildContext context) {
    final found = previewName != null;
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const IconTile(
                icon: Icons.diversity_1,
                bg: AppColors.secondaryContainer,
                fg: AppColors.onSecondaryContainer,
                size: 56,
                iconSize: 32,
                radius: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: AppPill(
                  l.gotInvite,
                  bg: AppColors.secondaryContainer.withAlpha(102),
                  fg: AppColors.onSecondaryContainer,
                  style: AppText.labelSm.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.joinCardTitle,
            style: AppText.headlineSm.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            l.joinCardBody,
            style: AppText.bodyMd.copyWith(
              color: AppColors.muted,
              height: 1.625,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        l.enterInviteCode,
                        style: AppText.labelMd.copyWith(color: AppColors.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.codeCharacters.toUpperCase(),
                      style: AppText.labelSm.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Stack(
                  alignment: AlignmentDirectional.centerEnd,
                  children: [
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppShadows.sm,
                      ),
                      child: TextField(
                        controller: code,
                        enabled: !vm.busy,
                        onChanged: (_) => onChanged(),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 100,
                        style: AppText.headlineSm.copyWith(
                          color: AppColors.text,
                          letterSpacing: 0.9,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: l.inviteCodeHint,
                          hintStyle: AppText.bodyMd.copyWith(color: _outline),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsetsDirectional.fromSTEB(
                            16,
                            0,
                            88,
                            0,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Material(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: vm.busy ? null : onPaste,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.content_paste,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l.paste,
                                  style: AppText.labelSm.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (found) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsetsDirectional.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 36,
                          color: AppColors.secondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      previewName!,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.labelMd.copyWith(
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const SizedBox.square(
                                    dimension: 6,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l.foundLabel,
                                    style: AppText.labelSm.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alreadyMember
                                    ? l.alreadyMember
                                    : l.membersActive(previewMembers ?? 0),
                                style: AppText.bodySm.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    errorText!,
                    style: AppText.bodySm.copyWith(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 14),
                AppCta(
                  label: found ? l.joinHousehold : l.findHousehold,
                  icon: found ? Icons.login : Icons.search,
                  loading: vm.busy,
                  onPressed: code.text.trim().isEmpty ? null : onSubmit,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.help_outline, size: 16, color: _outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.invalidCodeHelp,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.muted,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.l, required this.onFaq});
  final AppLocalizations l;
  final VoidCallback onFaq;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh.withAlpha(153),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: AppShadows.sm,
          ),
          child: const Icon(
            Icons.contact_support_outlined,
            size: 22,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.needHelpSetup,
                style: AppText.labelMd.copyWith(color: AppColors.text),
              ),
              Text(
                l.askResendCode,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onFaq,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: Text(
                l.faq,
                style: AppText.labelMd.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class CreateHouseholdView extends StatefulWidget {
  const CreateHouseholdView({super.key});
  @override
  State<CreateHouseholdView> createState() => _CreateHouseholdViewState();
}

class _CreateHouseholdViewState extends State<CreateHouseholdView> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _form = GlobalKey<FormState>();
  String avatar = 'cottage';
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = context.watch<SessionViewModel>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 32),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RoundIconButton(
                            icon: Icons.arrow_back,
                            tooltip: l.back,
                            onPressed: () => context.goNamed('selectHousehold'),
                          ),
                          AppPill(
                            l.householdConnectionStep.toUpperCase(),
                            icon: Icons.cottage,
                            bg: AppColors.surfaceContainer,
                            fg: AppColors.primary,
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            style: AppText.labelSm.copyWith(
                              letterSpacing: 0.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      l.createTitle,
                      style: AppText.headlineLg.copyWith(
                        color: AppColors.text,
                        letterSpacing: -0.65,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.createSubtitle,
                      style: AppText.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    _AvatarCard(
                      l: l,
                      selected: avatar,
                      onSelected: (key) => setState(() => avatar = key),
                    ),
                    const SizedBox(height: 20),
                    _FieldCard(
                      title: l.householdNameLabel,
                      required: true,
                      counter: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _name,
                        builder: (context, value, _) => Text(
                          '${value.text.characters.length}/40',
                          style: AppText.labelSm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      helper: l.visibleToMembers,
                      field: TextFormField(
                        controller: _name,
                        maxLength: 40,
                        style: AppText.bodyLg.copyWith(color: AppColors.text),
                        decoration: _plainField(
                          hint: l.householdNamePlaceholder,
                          suffix: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ),
                        validator: (value) =>
                            value == null ||
                                value.trim().isEmpty ||
                                value.trim().length > 100
                            ? l.requiredField
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FieldCard(
                      title: l.householdDescriptionLabel,
                      counter: Text(
                        l.optional.toUpperCase(),
                        style: AppText.labelSm.copyWith(color: AppColors.muted),
                      ),
                      helper: l.helpsStaySynced,
                      field: TextFormField(
                        controller: _description,
                        maxLength: 1000,
                        minLines: 3,
                        maxLines: 3,
                        style: AppText.bodyMd.copyWith(color: AppColors.text),
                        decoration: _plainField(hint: l.descriptionPlaceholder),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppCard(
                      color: AppColors.surfaceContainer,
                      radius: 12,
                      shadow: false,
                      padding: const EdgeInsetsDirectional.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsetsDirectional.only(top: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.adminNotice,
                                  style: AppText.titleMd.copyWith(
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l.adminDescription,
                                  style: AppText.bodySm.copyWith(
                                    color: AppColors.muted,
                                    height: 1.625,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (vm.errorCode != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 12),
                        child: Text(
                          l.householdError,
                          textAlign: TextAlign.center,
                          style: AppText.bodySm.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    AppCta(
                      label: l.createHousehold,
                      trailingIcon: Icons.arrow_forward,
                      loading: vm.switching,
                      onPressed: () async {
                        if (!_form.currentState!.validate()) return;
                        await vm.createHousehold(
                          _name.text,
                          description: _description.text.trim().isEmpty
                              ? null
                              : _description.text.trim(),
                          avatarKey: avatar,
                        );
                        if (context.mounted && vm.activeHousehold != null) {
                          context.goNamed('inviteFamily');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _plainField({required String hint, Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: AppText.bodyMd.copyWith(color: const Color(0xFFC4C5D7)),
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      focusColor: AppColors.surfaceLow,
      suffixIcon: suffix == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: suffix,
            ),
      suffixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
      contentPadding: const EdgeInsetsDirectional.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.title,
    required this.counter,
    required this.helper,
    required this.field,
    this.required = false,
  });
  final String title;
  final Widget counter;
  final String helper;
  final Widget field;
  final bool required;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 12,
    padding: const EdgeInsetsDirectional.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                text: title,
                children: [
                  if (required)
                    TextSpan(
                      text: ' *',
                      style: AppText.bodySm.copyWith(color: AppColors.danger),
                    ),
                ],
              ),
              style: AppText.labelMd.copyWith(color: AppColors.text),
            ),
            counter,
          ],
        ),
        const SizedBox(height: 8),
        field,
        const SizedBox(height: 8),
        Text(helper, style: AppText.bodySm.copyWith(color: AppColors.muted)),
      ],
    ),
  );
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.l,
    required this.selected,
    required this.onSelected,
  });
  final AppLocalizations l;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 12,
    padding: const EdgeInsetsDirectional.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.householdAvatar,
          style: AppText.labelMd.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                HouseholdAvatars.icon(selected),
                size: 38,
                color: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cottage,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.cozyIcon,
                          style: AppText.labelMd.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.selectedAvatar(HouseholdAvatars.label(l, selected)),
                    style: AppText.bodySm.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final key in HouseholdAvatars.keys)
              Material(
                color: key == selected
                    ? AppColors.surfaceHigh
                    : AppColors.surfaceLow,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onSelected(key),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      HouseholdAvatars.icon(key, filled: key == selected),
                      size: 22,
                      color: key == selected
                          ? AppColors.primary
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
